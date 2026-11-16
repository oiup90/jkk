import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/account_block_guard.dart';

void main() {
  testWidgets('periodic check catches a block missed by realtime', (
    tester,
  ) async {
    final events = StreamController<bool>();
    var blocked = false;
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountBlockGuard(
          events: () => events.stream,
          readBlocked: () async => blocked,
          isCurrentUser: () => true,
          signOut: () async {
            calls++;
          },
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    blocked = true;
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    unawaited(events.close());
  });

  testWidgets('a user already blocked at startup is signed out', (
    tester,
  ) async {
    final events = StreamController<bool>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountBlockGuard(
          events: () => events.stream,
          readBlocked: () async => true,
          isCurrentUser: () => true,
          signOut: () async {
            calls++;
          },
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    unawaited(events.close());
  });

  testWidgets('a block event signs out only once for the current user', (
    tester,
  ) async {
    final events = StreamController<bool>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountBlockGuard(
          events: () => events.stream,
          readBlocked: () async => false,
          isCurrentUser: () => true,
          signOut: () async {
            calls++;
          },
          child: const Text('Signed in'),
        ),
      ),
    );
    await tester.pump();
    events.add(true);
    events.add(true);
    await tester.pump();
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    unawaited(events.close());
  });

  testWidgets('initial check and reconnect detect a previously missed block', (
    tester,
  ) async {
    final events = StreamController<bool>();
    var blocked = false;
    var fail = true;
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountBlockGuard(
          events: () => events.stream,
          readBlocked: () async {
            if (fail) throw StateError('offline');
            return blocked;
          },
          isCurrentUser: () => true,
          signOut: () async {
            calls++;
          },
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(calls, 0);
    fail = false;
    blocked = true;
    events.add(false);
    await tester.pump();
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    unawaited(events.close());
  });

  testWidgets(
    'resume checks status and stale checks cannot sign out another user',
    (tester) async {
      final events = StreamController<bool>();
      final firstRead = Completer<bool>();
      var current = true;
      var calls = 0;
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AccountBlockGuard(
            events: () => events.stream,
            readBlocked: () {
              reads++;
              return reads == 1 ? firstRead.future : Future.value(true);
            },
            isCurrentUser: () => current,
            signOut: () async {
              calls++;
            },
            child: const SizedBox(),
          ),
        ),
      );
      current = false;
      firstRead.complete(true);
      await tester.pump();
      expect(calls, 0);
      current = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
      unawaited(events.close());
    },
  );
}
