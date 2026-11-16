import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support_page.dart';

String transferRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class WalletTransferPage extends StatefulWidget {
  const WalletTransferPage({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<WalletTransferPage> createState() => _WalletTransferPageState();
}

class _WalletTransferPageState extends State<WalletTransferPage> {
  final form = GlobalKey<FormState>();
  final wallet = TextEditingController(),
      amount = TextEditingController(),
      pin = TextEditingController();
  late final owner = widget.client.auth.currentUser!.id;
  String get storageKey => 'pending-wallet-transfer-$owner';
  Map<String, dynamic>? pending;
  bool busy = true, restoreFailed = false;
  String? error, receipt;
  String text(String en, String ml) => supportText(context, en, ml);
  bool get sameSession => widget.client.auth.currentUser?.id == owner;
  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(
        storageKey,
      );
      if (saved != null) {
        pending = Map<String, dynamic>.from(jsonDecode(saved) as Map);
        wallet.text = pending!['wallet'] as String;
        amount.text = '${pending!['amount']}';
      }
    } catch (_) {
      busy = false;
      restoreFailed = true;
      if (mounted) {
        setState(
          () => error = text(
            'Unable to restore transfer. Reopen this page before sending.',
            'Transfer വിവരങ്ങൾ ലഭിച്ചില്ല. ഈ page വീണ്ടും തുറക്കുക.',
          ),
        );
      }
      return;
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    wallet.dispose();
    amount.dispose();
    pin.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy ||
        restoreFailed ||
        !sameSession ||
        !form.currentState!.validate()) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(text('Confirm transfer', 'Transfer സ്ഥിരീകരിക്കുക')),
        content: Text(
          text(
            'Send ${amount.text} coins to wallet ${wallet.text}? Check the number carefully. Transfers cannot be cancelled.',
            '${wallet.text} വാലറ്റിലേക്ക് ${amount.text} coins അയയ്ക്കണോ? നമ്പർ പരിശോധിക്കുക. Transfer റദ്ദാക്കാനാകില്ല.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(text('Cancel', 'റദ്ദാക്കുക')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(text('Confirm', 'സ്ഥിരീകരിക്കുക')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !sameSession) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      pending ??= {
        'request': transferRequestId(),
        'wallet': wallet.text.trim(),
        'amount': int.parse(amount.text),
      };
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, jsonEncode(pending))) {
        throw StateError('Transfer could not be saved');
      }
      if (!sameSession) throw StateError('Session changed');
      final result = await widget.client.rpc(
        'transfer_wallet_coins',
        params: {
          'p_request': pending!['request'],
          'p_wallet': pending!['wallet'],
          'p_amount': pending!['amount'],
          'p_pin': pin.text,
        },
      );
      pin.clear();
      if (!mounted || !sameSession) return;
      if (result['status'] != 'ok') {
        final status = result['status'];
        setState(
          () => error = switch (status) {
            'pin_missing' => text(
              'Set your Security PIN in Profile first.',
              'ആദ്യം Profile-ൽ Security PIN സജ്ജമാക്കുക.',
            ),
            'pin_locked' => text(
              'PIN locked. Try again after 15 minutes.',
              'PIN lock ആയി. 15 മിനിറ്റിന് ശേഷം ശ്രമിക്കുക.',
            ),
            _ => text(
              'Incorrect PIN. Check and try again.',
              'PIN തെറ്റാണ്. പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
            ),
          },
        );
        // A returned PIN status guarantees that no transfer was made.
        if (await prefs.remove(storageKey)) pending = null;
        return;
      }
      receipt = result['id'] as String;
      await prefs.remove(storageKey);
      if (mounted) setState(() {});
    } on PostgrestException catch (failure) {
      pin.clear();
      // An explicit RPC rejection rolled back the operation. Network errors
      // retain the durable request ID so an uncertain result cannot be paid twice.
      if (failure.code == 'P0001') {
        final prefs = await SharedPreferences.getInstance();
        if (await prefs.remove(storageKey)) pending = null;
        if (mounted) {
          setState(() => error = failure.message);
        }
      } else if (mounted) {
        setState(
          () => error = text(
            'Transfer not confirmed. Retry with the same details.',
            'Transfer സ്ഥിരീകരിച്ചിട്ടില്ല. ഇതേ വിവരങ്ങളോടെ Retry ചെയ്യുക.',
          ),
        );
      }
    } catch (_) {
      pin.clear();
      if (mounted) {
        setState(
          () => error = text(
            'Transfer not confirmed. Retry with the same details to check safely; do not start another transfer.',
            'Transfer സ്ഥിരീകരിച്ചിട്ടില്ല. ഇതേ വിവരങ്ങളോടെ Retry ചെയ്യുക; മറ്റൊരു transfer തുടങ്ങരുത്.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text(text('Transfer coins', 'Coins അയയ്ക്കുക'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (receipt != null) ...[
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 56,
                ),
                Text(
                  text('Transfer completed', 'Transfer പൂർത്തിയായി'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SelectableText('${text('Receipt', 'രസീത്')}: $receipt'),
              ] else
                Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        text(
                          'Send coins to another member using their 10-digit wallet number. No transfer fee.',
                          'മറ്റൊരു അംഗത്തിന്റെ 10 അക്ക വാലറ്റ് നമ്പറിലേക്ക് coins അയയ്ക്കാം. Transfer fee ഇല്ല.',
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: wallet,
                        readOnly: busy || pending != null,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          labelText: text(
                            'Recipient wallet number',
                            'സ്വീകരിക്കുന്ന വാലറ്റ് നമ്പർ',
                          ),
                        ),
                        validator: (v) =>
                            RegExp(r'^[1-9][0-9]{9}$').hasMatch(v ?? '')
                            ? null
                            : text(
                                'Enter a valid 10-digit wallet number',
                                'ശരിയായ 10 അക്ക നമ്പർ നൽകുക',
                              ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amount,
                        readOnly: busy || pending != null,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          labelText: text('Coins', 'Coins'),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n != null && n > 0 && n <= 2147483647
                              ? null
                              : text(
                                  'Enter a positive whole coin amount',
                                  'ശരിയായ coin എണ്ണം നൽകുക',
                                );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: pin,
                        enabled: !busy,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          labelText: text('Security PIN', 'Security PIN'),
                        ),
                        validator: (v) => RegExp(r'^\d{4}$').hasMatch(v ?? '')
                            ? null
                            : text(
                                'Enter your 4-digit PIN',
                                '4 അക്ക PIN നൽകുക',
                              ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(error!),
                        ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: busy || restoreFailed ? null : send,
                        icon: const Icon(Icons.send),
                        label: Text(
                          text(
                            pending == null
                                ? 'Send coins'
                                : 'Retry / check transfer',
                            pending == null
                                ? 'Coins അയയ്ക്കുക'
                                : 'Retry / Transfer പരിശോധിക്കുക',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
