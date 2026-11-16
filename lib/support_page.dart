import 'dart:async';

import 'package:flutter/material.dart';

import 'design.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

String supportText(BuildContext c, String en, String ml) =>
    Localizations.localeOf(c).languageCode == 'ml' ? ml : en;

class SupportPage extends StatefulWidget {
  const SupportPage({super.key, required this.client, this.loadTickets});
  final SupabaseClient client;
  final Future<List<dynamic>> Function()? loadTickets;
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  late Future<List<dynamic>> tickets;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    tickets =
        widget.loadTickets?.call() ??
        widget.client.rpc('support_my_tickets').then((v) => v as List<dynamic>);
  }

  void refresh() => setState(load);
  Future<void> create() async {
    final message = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          supportText(c, 'Start support chat', 'Support chat തുടങ്ങുക'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: message,
              maxLength: 2000,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: supportText(c, 'Message', 'സന്ദേശം'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(supportText(c, 'Cancel', 'റദ്ദാക്കുക')),
          ),
          FilledButton(
            onPressed: () {
              if (message.text.trim().isNotEmpty) {
                Navigator.pop(c, [
                  String.fromCharCodes(message.text.trim().runes.take(80)),
                  message.text.trim(),
                ]);
              }
            },
            child: Text(supportText(c, 'Send', 'അയയ്ക്കുക')),
          ),
        ],
      ),
    );
    message.dispose();
    if (result == null || !mounted) return;
    try {
      final id = await widget.client.rpc(
        'support_create_ticket',
        params: {'p_subject': result[0], 'p_body': result[1]},
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SupportConversation(
            client: widget.client,
            id: id as String,
            subject: result[0],
            open: true,
          ),
        ),
      );
      if (mounted) refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              supportText(
                context,
                'Unable to send ticket.',
                'Ticket അയയ്ക്കാനായില്ല.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(supportText(context, 'Support', 'സഹായം')),
      actions: [
        IconButton(
          onPressed: refresh,
          tooltip: supportText(context, 'Refresh', 'പുതുക്കുക'),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: create,
      icon: const Icon(Icons.add),
      label: Text(supportText(context, 'New chat', 'പുതിയ chat')),
    ),
    body: FutureBuilder<List<dynamic>>(
      future: tickets,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: Text(
              supportText(c, 'Unable to load tickets.', 'Tickets ലഭ്യമല്ല.'),
            ),
          );
        }
        final rows = s.data ?? [];
        if (rows.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              child: GrowthEmpty(
                art: 'support',
                artHeight: 220,
                title: supportText(
                  c,
                  'Chat with support',
                  'Support-നോട് chat ചെയ്യാം',
                ),
                subtitle: supportText(
                  c,
                  'Start a chat and our team will reply here.',
                  'Chat തുടങ്ങുക. Team ഇവിടെ മറുപടി നൽകും.',
                ),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: rows.length,
          itemBuilder: (c, i) {
            final r = rows[i] as Map;
            return Card(
              child: ListTile(
                title: Text('${r['subject']}'),
                subtitle: Text('${r['status']} · ${r['updated_at']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    c,
                    MaterialPageRoute<void>(
                      builder: (_) => SupportConversation(
                        client: widget.client,
                        id: r['id'] as String,
                        subject: r['subject'] as String,
                        open: r['status'] == 'open',
                      ),
                    ),
                  );
                  if (mounted) refresh();
                },
              ),
            );
          },
        );
      },
    ),
  );
}

class SupportConversation extends StatefulWidget {
  const SupportConversation({
    super.key,
    required this.client,
    required this.id,
    required this.subject,
    required this.open,
    this.admin = false,
  });
  final SupabaseClient client;
  final String id, subject;
  final bool open, admin;
  @override
  State<SupportConversation> createState() => _SupportConversationState();
}

class _SupportConversationState extends State<SupportConversation>
    with WidgetsBindingObserver {
  Timer? poll;
  final message = TextEditingController();
  late Future<List<dynamic>> data;
  bool busy = false, loadingMessages = false;
  @override
  void initState() {
    super.initState();
    load();
    WidgetsBinding.instance.addObserver(this);
    startPolling();
  }

  void startPolling() {
    poll?.cancel();
    poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted &&
          !busy &&
          !loadingMessages &&
          ModalRoute.of(context)?.isCurrent == true) {
        setState(load);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startPolling();
      setState(load);
    } else {
      poll?.cancel();
    }
  }

  void load() {
    loadingMessages = true;
    data = widget.client
        .rpc('support_messages', params: {'p_ticket': widget.id})
        .then((v) => v as List<dynamic>)
        .whenComplete(() => loadingMessages = false);
  }

  @override
  void dispose() {
    poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    message.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || message.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await widget.client.rpc(
        'support_reply',
        params: {'p_ticket': widget.id, 'p_body': message.text.trim()},
      );
      message.clear();
      if (mounted) setState(load);
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.subject),
      actions: [
        IconButton(
          onPressed: () => setState(load),
          icon: const Icon(Icons.refresh),
          tooltip: supportText(context, 'Refresh', 'പുതുക്കുക'),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: data,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done && !s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.hasError) {
                return Center(
                  child: Text(
                    supportText(
                      c,
                      'Unable to load messages.',
                      'സന്ദേശങ്ങൾ ലഭ്യമല്ല.',
                    ),
                  ),
                );
              }
              final messages = s.data ?? [];
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (c, index) {
                  final item = messages[messages.length - 1 - index];
                  final mine = (item['is_admin'] == true) == widget.admin;
                  final timestamp = DateTime.tryParse('${item['created_at']}')
                      ?.toLocal();
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(c).width * .78,
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: mine ? growthPurple : const Color(0xffeee6ff),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mine
                                ? supportText(c, 'You', 'നിങ്ങൾ')
                                : supportText(c, 'Support', 'സഹായം'),
                            style: TextStyle(
                              fontSize: 11,
                              color: mine ? Colors.white70 : growthPurple,
                            ),
                          ),
                          SelectableText(
                            '${item['body']}',
                            style: TextStyle(
                              color: mine ? Colors.white : growthInk,
                            ),
                          ),
                          if (timestamp != null)
                            Text(
                              '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                color: mine ? Colors.white70 : Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (!widget.open)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              supportText(
                context,
                'This chat is closed. Start a new chat for more help.',
                'ഈ chat അവസാനിച്ചു. കൂടുതൽ സഹായത്തിന് പുതിയ chat തുടങ്ങുക.',
              ),
            ),
          ),
        if (widget.open)
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
                        labelText: supportText(context, 'Reply', 'മറുപടി'),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: busy ? null : send,
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
