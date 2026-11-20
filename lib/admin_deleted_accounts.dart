import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDeletedAccounts extends StatefulWidget {
  const AdminDeletedAccounts({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<AdminDeletedAccounts> createState() => _AdminDeletedAccountsState();
}

class _AdminDeletedAccountsState extends State<AdminDeletedAccounts> {
  final search = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  int offset = 0;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({int page = 0}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await widget.client.rpc(
        'admin_deleted_accounts',
        params: {'p_query': search.text.trim(), 'p_offset': page},
      );
      if (mounted) {
        setState(() {
          rows = List<Map<String, dynamic>>.from(value as List);
          offset = page;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to load deleted accounts. Retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(Map<String, dynamic> row) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final data = await widget.client.rpc(
        'admin_deleted_account_snapshot',
        params: {'p_id': row['id']},
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              _SnapshotPage(data: Map<String, dynamic>.from(data as Map)),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to open archive. Retry.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Deleted accounts audit')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Account data retained at deletion for administrator audit. Archives begin from this feature’s deployment; earlier deleted records cannot be recovered.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: search,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Search email, name or user ID',
          ),
          onSubmitted: (_) => load(),
        ),
        FilledButton(
          onPressed: busy ? null : () => load(),
          child: const Text('Search / refresh'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        if (!busy && rows.isEmpty && error == null)
          const Text('No deleted accounts found.'),
        for (final row in rows)
          Card(
            child: ListTile(
              title: Text(row['email'] as String? ?? row['user_id'] as String),
              subtitle: Text(
                '${row['display_name'] ?? ''}\n${row['user_id']}\nDeleted: ${row['deleted_at']}',
              ),
              trailing: const Icon(Icons.folder_open),
              onTap: busy ? null : () => open(row),
            ),
          ),
        Row(
          children: [
            TextButton(
              onPressed: busy || offset == 0
                  ? null
                  : () => load(page: offset - 50),
              child: const Text('Previous'),
            ),
            TextButton(
              onPressed: busy || rows.length < 50
                  ? null
                  : () => load(page: offset + 50),
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SnapshotPage extends StatelessWidget {
  const _SnapshotPage({required this.data});
  final Map<String, dynamic> data;
  Future<void> export(BuildContext context) async {
    try {
      final path = await getSaveLocation(
        suggestedName: 'deleted-account-${data['archive_id']}.json',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'JSON audit archive', extensions: ['json']),
        ],
      );
      if (path == null) return;
      await XFile.fromData(
        Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
        ),
        mimeType: 'application/json',
      ).saveTo(path.path);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Audit archive saved.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save archive.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = Map<String, dynamic>.from(data['data'] as Map);
    return Scaffold(
      appBar: AppBar(title: const Text('Deleted account audit')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Deleted: ${data['deleted_at']}'),
          FilledButton.icon(
            onPressed: () => export(context),
            icon: const Icon(Icons.download),
            label: const Text('Download full audit JSON'),
          ),
          for (final entry in snapshot.entries)
            ExpansionTile(
              title: Text(
                '${entry.key}${entry.value is List ? ' (${(entry.value as List).length})' : ''}',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(entry.value),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
