import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A true event is a block; false asks the guard to reconcile after connecting.
Stream<bool> accountBlockEvents(SupabaseClient client, String userId) {
  late StreamController<bool> controller;
  RealtimeChannel? channel;
  controller = StreamController<bool>(
    onListen: () {
      channel = client
          .channel('account-block:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'account_block_status',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              if (!controller.isClosed &&
                  payload.newRecord['blocked'] == true) {
                controller.add(true);
              }
            },
          )
          .subscribe((status, _) {
            if (!controller.isClosed &&
                status == RealtimeSubscribeStatus.subscribed) {
              controller.add(false);
            }
          });
    },
    onCancel: () async {
      final current = channel;
      if (current != null) await client.removeChannel(current);
    },
  );
  return controller.stream;
}

Future<bool> accountIsBlocked(SupabaseClient client, String userId) async {
  final row = await client
      .from('account_block_status')
      .select('blocked')
      .eq('user_id', userId)
      .maybeSingle();
  return row?['blocked'] == true;
}

class AccountBlockGuard extends StatefulWidget {
  const AccountBlockGuard({
    super.key,
    required this.events,
    required this.readBlocked,
    required this.isCurrentUser,
    required this.signOut,
    required this.child,
  });
  final Stream<bool> Function() events;
  final Future<bool> Function() readBlocked;
  final bool Function() isCurrentUser;
  final Future<void> Function() signOut;
  final Widget child;

  @override
  State<AccountBlockGuard> createState() => _AccountBlockGuardState();
}

class _AccountBlockGuardState extends State<AccountBlockGuard>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? subscription;
  Timer? refreshTimer;
  bool signingOut = false;
  bool checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subscription = widget.events().listen(
      (blocked) => blocked ? _signOut() : _refresh(),
      onError: (Object _) {},
    );
    _refresh();
    refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(),
    );
  }

  Future<void> _refresh() async {
    if (!mounted || signingOut || checking) return;
    checking = true;
    try {
      if (await widget.readBlocked().timeout(const Duration(seconds: 10))) {
        _signOut();
      }
    } catch (_) {
      // The database still enforces the block. Retry on the next check.
    } finally {
      checking = false;
    }
  }

  void _signOut() {
    if (!mounted || signingOut || !widget.isCurrentUser()) return;
    signingOut = true;
    unawaited(
      widget.signOut().catchError((Object _) {
        if (mounted) signingOut = false;
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    unawaited(subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
