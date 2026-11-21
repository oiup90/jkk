import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support_page.dart';
import 'user_page_canvas.dart';

/// A device-held capability gives a signed-out visitor access to their chat.
class GuestSupportPage extends StatefulWidget {
  const GuestSupportPage({
    super.key,
    required this.client,
    required this.project,
    this.loadKey,
  });
  final SupabaseClient client;
  final String project;
  final Future<String> Function()? loadKey;

  @override
  State<GuestSupportPage> createState() => _GuestSupportPageState();
}

class _GuestSupportPageState extends State<GuestSupportPage>
    with WidgetsBindingObserver {
  final storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );
  final message = TextEditingController();
  String? keyValue;
  Map<String, dynamic>? conversation;
  Timer? timer;
  bool loading = true, busy = false, failed = false, newChat = false;
  int refreshVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true && !busy) {
        refresh();
      }
    });
  }

  Future<void> initialize() async {
    try {
      final storageKey = 'guest-support-${widget.project}';
      var key = await (widget.loadKey?.call() ?? storage.read(key: storageKey));
      if (key == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
        final random = Random.secure();
        key = List.generate(
          32,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        await storage.write(key: storageKey, value: key);
      }
      keyValue = key;
      await refresh();
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<void> refresh() async {
    if (keyValue == null) return;
    final version = ++refreshVersion;
    try {
      final result = await widget.client.rpc(
        'guest_support_get',
        params: {'p_key': keyValue},
      );
      if (mounted && version == refreshVersion) {
        setState(() {
          conversation = result == null
              ? null
              : Map<String, dynamic>.from(result as Map);
          loading = false;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted && version == refreshVersion) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<void> send() async {
    if (busy || keyValue == null || message.text.trim().isEmpty) return;
    final draft = message.text;
    setState(() => busy = true);
    try {
      await widget.client.rpc(
        'guest_support_send',
        params: {'p_key': keyValue, 'p_body': draft.trim(), 'p_new': newChat},
      );
      if (!mounted) return;
      if (message.text == draft) message.clear();
      newChat = false;
      await refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              supportText(
                context,
                'Unable to send message.',
                'സന്ദേശം അയയ്ക്കാനായില്ല.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final closed = conversation?['status'] == 'closed' && !newChat;
    final messages = (conversation?['messages'] as List<dynamic>?) ?? [];
    return UserPageScaffold(
      identity: UserPageIdentity.conversation,
      appBar: AppBar(
        title: Text(
          supportText(context, 'Customer Support', 'Customer Support'),
        ),
        actions: [
          IconButton(
            onPressed: keyValue == null ? initialize : refresh,
            tooltip: supportText(context, 'Refresh', 'പുതുക്കുക'),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              supportText(
                context,
                'Include your account email if needed. Never send your password or Security PIN. This chat is available on this device.',
                'ആവശ്യമെങ്കിൽ അക്കൗണ്ട് ഇമെയിൽ നൽകുക. Password അല്ലെങ്കിൽ Security PIN അയയ്ക്കരുത്. ഈ chat ഈ device-ൽ ലഭ്യമാണ്.',
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : failed
                ? Center(
                    child: Text(
                      supportText(
                        context,
                        'Unable to load messages. Tap refresh to retry.',
                        'സന്ദേശങ്ങൾ ലഭ്യമല്ല. വീണ്ടും ശ്രമിക്കാൻ refresh ചെയ്യുക.',
                      ),
                    ),
                  )
                : messages.isEmpty || newChat
                ? Center(
                    child: Text(
                      supportText(
                        context,
                        'Start a chat and our team will reply here.',
                        'Chat തുടങ്ങുക. Team ഇവിടെ മറുപടി നൽകും.',
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final item = messages[messages.length - index - 1] as Map;
                      final mine = item['is_admin'] != true;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  mine
                                      ? supportText(context, 'You', 'നിങ്ങൾ')
                                      : supportText(
                                          context,
                                          'Support',
                                          'സഹായം',
                                        ),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                SelectableText('${item['body']}'),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (closed)
            TextButton(
              onPressed: () => setState(() => newChat = true),
              child: Text(supportText(context, 'New chat', 'പുതിയ chat')),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: message,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: supportText(context, 'Message', 'സന്ദേശം'),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: busy || loading || failed ? null : send,
                      child: Text(supportText(context, 'Send', 'അയയ്ക്കുക')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
