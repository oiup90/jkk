import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReleaseActivity extends StatefulWidget {
  const AdminReleaseActivity({
    super.key,
    required this.client,
    required this.releaseId,
    this.loader,
    this.changes,
  });
  final SupabaseClient client;
  final String releaseId;
  final Future<List<Map<String, dynamic>>> Function(int offset)? loader;
  final Stream<void>? changes;
  @override
  State<AdminReleaseActivity> createState() => _AdminReleaseActivityState();
}

class _AdminReleaseActivityState extends State<AdminReleaseActivity> {
  RealtimeChannel? channel;
  StreamSubscription<void>? subscription;
  Timer? timer;
  bool expanded = false, loading = false, live = false;
  int offset = 0, generation = 0;
  String? error;
  List<Map<String, dynamic>> rows = [];
  Future<void> load() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = widget.loader != null
          ? await widget.loader!(offset)
          : (await widget.client.rpc(
              'admin_release_installations',
              params: {'p_release': widget.releaseId, 'p_offset': offset},
            ) as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      if (mounted && request == generation) setState(() => rows = data);
    } catch (_) {
      if (mounted && request == generation) {
        setState(() => error = 'Unable to load installation reports. Retry.');
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  void start() {
    load();
    if (widget.changes != null) {
      subscription = widget.changes!.listen((_) => load());
      live = true;
    } else {
      channel = widget.client
          .channel(
            'installations-${widget.releaseId}-${identityHashCode(this)}',
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_installations',
            callback: (_) {
              if (mounted && expanded) load();
            },
          )
          .subscribe((status, _) {
            if (mounted) {
              setState(
                () => live = status == RealtimeSubscribeStatus.subscribed,
              );
            }
          });
    }
    timer = Timer.periodic(const Duration(seconds: 30), (_) => load());
  }

  void stop() {
    generation++;
    timer?.cancel();
    subscription?.cancel();
    if (channel != null) widget.client.removeChannel(channel!);
    channel = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  String date(dynamic value) =>
      DateTime.tryParse('$value')?.toLocal().toString().split('.').first ??
      'Not reported';
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Live installation reports'),
    subtitle: Text(
      expanded
          ? (live
                ? 'Live · updates as members report their build'
                : 'Connecting · refreshes every 30 seconds')
          : 'See who has updated and who is awaiting an update',
    ),
    leading: Icon(Icons.sensors, color: live ? const Color(0xff187d68) : null),
    onExpansionChanged: (value) {
      setState(() => expanded = value);
      if (value) {
        start();
      } else {
        stop();
      }
    },
    children: [
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'An installed version is reported when the member opens this version of the app online. Older apps may not report. A download alone is not an installation.',
        ),
      ),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Text(error!),
      if (!loading && error == null && rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No members in this audience.'),
        ),
      for (final row in rows)
        ListTile(
          leading: Icon(
            row['updated'] == true ? Icons.verified_rounded : Icons.schedule,
            color: row['updated'] == true
                ? const Color(0xff187d68)
                : const Color(0xff93621c),
          ),
          title: Text(
            '${row['display_name'] == '' ? row['email'] : row['display_name']}',
          ),
          subtitle: Text(
            '${row['email']}\n${row['updated'] == true ? 'Updated (reported)' : 'Awaiting update'} · Build ${row['version_code'] ?? 'unknown'}\nVersion reported: ${date(row['version_reported_at'])} · Last seen: ${date(row['last_seen_at'])}',
          ),
        ),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          TextButton(
            onPressed: loading || offset == 0
                ? null
                : () {
                    offset -= 50;
                    load();
                  },
            child: const Text('Previous reports'),
          ),
          Text(
            'Showing ${rows.isEmpty ? 0 : offset + 1}–${offset + rows.length}',
          ),
          TextButton(
            onPressed: loading || rows.length < 50
                ? null
                : () {
                    offset += 50;
                    load();
                  },
            child: const Text('Next reports'),
          ),
          IconButton(
            tooltip: 'Refresh installation reports',
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    ],
  );
}
