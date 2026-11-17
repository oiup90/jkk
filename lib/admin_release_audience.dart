import 'package:flutter/material.dart';

import 'admin_notifications.dart';

/// Uses the existing authorized member search; the UUID is kept out of manual input.
class AdminReleaseAudience extends StatefulWidget {
  const AdminReleaseAudience({
    super.key,
    required this.gateway,
    required this.enabled,
    required this.onChanged,
  });
  final AdminNotificationGateway gateway;
  final bool enabled;
  final ValueChanged<Map<String, dynamic>?> onChanged;
  @override
  State<AdminReleaseAudience> createState() => _AdminReleaseAudienceState();
}

class _AdminReleaseAudienceState extends State<AdminReleaseAudience> {
  final query = TextEditingController();
  bool specific = false, loading = false;
  String? error, selected;
  int offset = 0;
  List<Map<String, dynamic>> users = [];
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search(int start) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await widget.gateway.search(query.text.trim(), start);
      if (mounted) {
        setState(() {
          users = rows;
          offset = start;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to search members. Retry.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Specific user only'),
        subtitle: Text(
          specific
              ? 'Select a member below. This release will only be offered to them.'
              : 'All active users will receive this release.',
        ),
        value: specific,
        onChanged: !widget.enabled || loading
            ? null
            : (v) {
                setState(() {
                  specific = v;
                  selected = null;
                });
                widget.onChanged(v ? <String, dynamic>{} : null);
              },
      ),
      if (specific) ...[
        TextField(
          controller: query,
          enabled: widget.enabled && !loading,
          onSubmitted: (_) => search(0),
          decoration: InputDecoration(
            labelText: 'Find release recipient',
            hintText: 'Name, email or public user ID',
            suffixIcon: IconButton(
              tooltip: 'Search release recipient',
              onPressed: widget.enabled && !loading ? () => search(0) : null,
              icon: const Icon(Icons.search),
            ),
          ),
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        for (final user in users)
          ListTile(
            selected: selected == user['id'],
            leading: Icon(
              selected == user['id']
                  ? Icons.check_circle
                  : Icons.person_outline,
            ),
            title: Text('${user['display_name'] ?? user['email']}'),
            subtitle: Text('${user['email']} · ${user['public_id'] ?? ''}'),
            onTap: !widget.enabled
                ? null
                : () {
                    setState(() => selected = user['id'] as String);
                    widget.onChanged(user);
                  },
          ),
        if (!loading && users.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Search and select an active member before publishing.',
            ),
          ),
        Wrap(
          children: [
            TextButton(
              onPressed: widget.enabled && !loading && offset > 0
                  ? () => search(offset - 25)
                  : null,
              child: const Text('Previous members'),
            ),
            TextButton(
              onPressed: widget.enabled && !loading && users.length == 25
                  ? () => search(offset + 25)
                  : null,
              child: const Text('Next members'),
            ),
          ],
        ),
      ],
    ],
  );
}
