import 'user_page_canvas.dart';
import 'design.dart';
import 'user_tokens.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support_page.dart';
import 'user_localization.dart';

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
  Timer? lookupTimer;
  String? recipientName, recipientId, error;
  String lookupState = 'idle';
  int lookupGeneration = 0;
  bool busy = true, restoreFailed = false;
  String text(String en, String ml) => supportText(context, en, ml);
  bool get sameSession => widget.client.auth.currentUser?.id == owner;

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    // Capture the owner before preferences can yield to a session change.
    final key = storageKey;
    try {
      final saved = (await SharedPreferences.getInstance()).getString(key);
      if (!mounted || !sameSession) return;
      if (saved != null) {
        final value = Map<String, dynamic>.from(jsonDecode(saved) as Map);
        if (value['request'] is! String ||
            value['wallet'] is! String ||
            value['amount'] is! int) {
          throw const FormatException('Invalid pending transfer');
        }
        pending = value;
        wallet.text = value['wallet'] as String;
        amount.text = '${value['amount']}';
        recipientName = value['name'] as String?;
        recipientId = value['recipient_id'] as String?;
      }
    } catch (_) {
      restoreFailed = true;
      if (mounted) {
        setState(
          () => error = text(
            'Unable to restore transfer. Reopen this page before sending.',
            'Transfer വിവരങ്ങൾ ലഭിച്ചില്ല. ഈ page വീണ്ടും തുറക്കുക.',
          ),
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    lookupTimer?.cancel();
    wallet.dispose();
    amount.dispose();
    pin.dispose();
    super.dispose();
  }

  void walletChanged(String value) {
    lookupTimer?.cancel();
    final generation = ++lookupGeneration;
    setState(() {
      recipientName = null;
      recipientId = null;
      lookupState = RegExp(r'^[1-9][0-9]{9}$').hasMatch(value)
          ? 'checking'
          : 'idle';
    });
    if (lookupState == 'checking') {
      lookupTimer = Timer(
        const Duration(milliseconds: 350),
        () => lookup(value, generation),
      );
    }
  }

  Future<void> lookup(String number, int generation) async {
    try {
      final response = await widget.client
          .rpc('lookup_wallet_recipient', params: {'p_wallet': number})
          .timeout(const Duration(seconds: 15));
      if (!mounted ||
          !sameSession ||
          wallet.text != number ||
          pending != null ||
          generation != lookupGeneration) {
        return;
      }
      final data = Map<String, dynamic>.from(response as Map);
      setState(() {
        if (data['status'] == 'found' &&
            data['name'] is String &&
            (data['name'] as String).isNotEmpty &&
            data['recipient_id'] is String &&
            RegExp(r'^[0-9]{8}$').hasMatch(data['recipient_id'] as String)) {
          recipientName = data['name'] as String;
          recipientId = data['recipient_id'] as String;
          lookupState = 'found';
        } else {
          lookupState = data['status'] == 'not_found' ? 'missing' : 'error';
        }
      });
    } catch (_) {
      if (mounted &&
          sameSession &&
          wallet.text == number &&
          pending == null &&
          generation == lookupGeneration) {
        setState(() => lookupState = 'error');
      }
    }
  }

  Future<void> send() async {
    if (busy ||
        restoreFailed ||
        !sameSession ||
        !form.currentState!.validate()) {
      return;
    }
    if (pending == null && (lookupState != 'found' || recipientName == null)) {
      return;
    }
    final displayName = recipientName ?? text('Recipient', 'സ്വീകരിക്കുന്നയാൾ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(text('Confirm transfer', 'Transfer സ്ഥിരീകരിക്കുക')),
        content: Text(
          userTransferConfirmation(
            context,
            amount: amount.text,
            name: displayName,
            wallet: wallet.text,
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
    final wasPending = pending != null;
    var saved = false;
    try {
      pending ??= {
        'request': transferRequestId(),
        'wallet': wallet.text.trim(),
        'amount': int.parse(amount.text),
        'name': recipientName,
        'recipient_id': recipientId,
      };
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, jsonEncode(pending))) {
        throw StateError('Transfer could not be saved');
      }
      saved = true;
      if (!sameSession || !mounted) return;
      final request = Map<String, dynamic>.from(pending!);
      final submittedPin = pin.text;
      pin.clear();
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => _PaymentProcessingPage(
            isMalayalam: Localizations.localeOf(context).languageCode == 'ml',
            run: () => performPayment(request, submittedPin, prefs),
          ),
        ),
      );
    } catch (_) {
      if (!wasPending && !saved) pending = null;
      pin.clear();
      if (mounted) {
        setState(
          () => error = text(
            saved
                ? 'Transfer not confirmed. Retry with the same details.'
                : 'Unable to save transfer. Please try again.',
            saved
                ? 'Transfer സ്ഥിരീകരിച്ചിട്ടില്ല. ഇതേ വിവരങ്ങളോടെ വീണ്ടും ശ്രമിക്കുക.'
                : 'Transfer വിവരങ്ങൾ സൂക്ഷിക്കാൻ കഴിഞ്ഞില്ല. വീണ്ടും ശ്രമിക്കുക.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<_PaymentOutcome> performPayment(
    Map<String, dynamic> request,
    String submittedPin,
    SharedPreferences prefs,
  ) async {
    _PaymentOutcome unknown() => _PaymentOutcome(
      status: 'unknown',
      wallet: request['wallet'] as String,
      amount: request['amount'] as int,
      name: request['name'] as String? ?? '',
    );
    try {
      final value = await widget.client
          .rpc(
            'pay_wallet_coins',
            params: {
              'p_request': request['request'],
              'p_wallet': request['wallet'],
              'p_amount': request['amount'],
              'p_pin': submittedPin,
              'p_recipient_id': request['recipient_id'],
            },
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted || !sameSession) return unknown();
      final data = Map<String, dynamic>.from(value as Map);
      final status = data['status'];
      final reference = data['reference'];
      final date = DateTime.tryParse(data['created_at'] as String? ?? '');
      if ((status != 'success' && status != 'failure') ||
          reference is! String ||
          !RegExp(r'^\d{12}$').hasMatch(reference) ||
          data['wallet'] != request['wallet'] ||
          data['amount'] != request['amount'] ||
          data['name'] is! String ||
          date == null) {
        return unknown();
      }
      final result = _PaymentOutcome(
        status: status as String,
        wallet: data['wallet'] as String,
        name: data['name'] as String,
        amount: data['amount'] as int,
        reference: reference,
        date: date,
        failureCode: data['failure_code'] as String?,
      );
      // If local cleanup fails, keep the same request for a safe retry.
      var removed = false;
      try {
        removed = await prefs.remove(storageKey);
      } catch (_) {
        // The server result is still final; retain the request for a safe retry.
      }
      if (removed) {
        pending = null;
        if (mounted) {
          setState(() {
            wallet.clear();
            amount.clear();
            recipientName = null;
            recipientId = null;
            lookupState = 'idle';
          });
        }
      }
      return result;
    } catch (_) {
      return unknown();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: UserPageScaffold(
      identity: UserPageIdentity.transfer,
      appBar: AppBar(title: Text(text('Transfer coins', 'Coins അയയ്ക്കുക'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              UserSectionIntro(
                title: text(
                  'Send coins securely',
                  'സുരക്ഷിതമായി coins അയയ്ക്കുക',
                ),
                subtitle: text(
                  'Enter a wallet number to find the recipient. No transfer fee.',
                  'സ്വീകരിക്കുന്നയാളെ കണ്ടെത്താൻ wallet നമ്പർ നൽകുക. Transfer fee ഇല്ല.',
                ),
                icon: Icons.swap_horiz_rounded,
                accent: userTeal,
              ),
              const SizedBox(height: 20),
              if (busy) const LinearProgressIndicator(),
              Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: wallet,
                      readOnly: busy || pending != null,
                      onChanged: walletChanged,
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
                        prefixIcon: const Icon(
                          Icons.account_balance_wallet_outlined,
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
                    if (lookupState == 'checking')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          text('Checking wallet…', 'Wallet പരിശോധിക്കുന്നു…'),
                        ),
                      ),
                    if (lookupState == 'found' ||
                        (pending != null && recipientName != null))
                      _RecipientNotice(
                        name: recipientName!,
                        isMalayalam:
                            Localizations.localeOf(context).languageCode ==
                            'ml',
                      ),
                    if (lookupState == 'missing')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          text(
                            'Wallet number not found.',
                            'Wallet നമ്പർ കണ്ടെത്തിയില്ല.',
                          ),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (lookupState == 'error')
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              text(
                                'Unable to check wallet.',
                                'Wallet പരിശോധിക്കാൻ കഴിഞ്ഞില്ല.',
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => walletChanged(wallet.text),
                            child: Text(text('Retry', 'വീണ്ടും ശ്രമിക്കുക')),
                          ),
                        ],
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
                        prefixIcon: const Icon(Icons.toll),
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
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) => RegExp(r'^\d{4}$').hasMatch(v ?? '')
                          ? null
                          : text('Enter your 4-digit PIN', '4 അക്ക PIN നൽകുക'),
                    ),
                    if (pending != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          text(
                            'Previous transfer not confirmed. Retry with the same details.',
                            'മുമ്പത്തെ transfer സ്ഥിരീകരിച്ചിട്ടില്ല. ഇതേ വിവരങ്ങളോടെ വീണ്ടും പരിശോധിക്കുക.',
                          ),
                        ),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed:
                          busy ||
                              restoreFailed ||
                              (pending == null && lookupState != 'found')
                          ? null
                          : send,
                      icon: const Icon(Icons.lock_outline),
                      label: Text(
                        pending == null
                            ? text('Pay now', 'Pay now')
                            : text(
                                'Retry / check transfer',
                                'Retry / Transfer പരിശോധിക്കുക',
                              ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
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

class _RecipientNotice extends StatelessWidget {
  const _RecipientNotice({required this.name, required this.isMalayalam});
  final String name;
  final bool isMalayalam;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xffeaf7ee),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.verified_user_outlined, color: Color(0xff1c7a46)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userText(
                  context,
                  'Recipient',
                  'സ്വീകരിക്കുന്നയാൾ',
                  forceMalayalam: isMalayalam,
                ),
                style: const TextStyle(color: Color(0xff416b50), fontSize: 11),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xff194f30),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PaymentOutcome {
  const _PaymentOutcome({
    required this.status,
    required this.wallet,
    required this.name,
    required this.amount,
    this.reference,
    this.date,
    this.failureCode,
  });
  final String status, wallet, name;
  final int amount;
  final String? reference, failureCode;
  final DateTime? date;
}

class _PaymentProcessingPage extends StatefulWidget {
  const _PaymentProcessingPage({required this.run, required this.isMalayalam});
  final Future<_PaymentOutcome> Function() run;
  final bool isMalayalam;
  @override
  State<_PaymentProcessingPage> createState() => _PaymentProcessingPageState();
}

class _PaymentProcessingPageState extends State<_PaymentProcessingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..forward();
  @override
  void initState() {
    super.initState();
    process();
  }

  Future<void> process() async {
    final result = widget.run();
    await Future<void>.delayed(const Duration(seconds: 5));
    final outcome = await result;
    if (!mounted) return;
    await Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute(
        builder: (_) => _PaymentResultPage(
          outcome: outcome,
          isMalayalam: widget.isMalayalam,
        ),
      ),
    );
  }

  @override
  void dispose() {
    progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: UserPageScaffold(
      identity: UserPageIdentity.processing,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: progress,
                  builder: (_, _) => SizedBox(
                    width: 110,
                    height: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: progress.value,
                            strokeWidth: 7,
                            backgroundColor: const Color(0xffe9ddfb),
                          ),
                        ),
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(0xff5d24c8),
                          size: 44,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  userText(
                    context,
                    'Processing payment',
                    'Payment പരിശോധിക്കുന്നു',
                    forceMalayalam: widget.isMalayalam,
                  ),
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  userText(
                    context,
                    'Please wait while we confirm your transfer.',
                    'ദയവായി കാത്തിരിക്കൂ…',
                    forceMalayalam: widget.isMalayalam,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PaymentResultPage extends StatelessWidget {
  const _PaymentResultPage({required this.outcome, required this.isMalayalam});
  final _PaymentOutcome outcome;
  final bool isMalayalam;
  @override
  Widget build(BuildContext context) {
    String text(String en, String ml) =>
        userText(context, en, ml, forceMalayalam: isMalayalam);
    final success = outcome.status == 'success';
    final unknown = outcome.status == 'unknown';
    final color = unknown
        ? const Color(0xffa46b12)
        : success
        ? const Color(0xff21814d)
        : const Color(0xffb83945);
    final title = unknown
        ? text('Transfer not confirmed', 'Transfer സ്ഥിരീകരിച്ചിട്ടില്ല')
        : success
        ? text('Payment successful', 'Payment വിജയിച്ചു')
        : text('Payment failed', 'Payment പരാജയപ്പെട്ടു');
    final detail = unknown
        ? text(
            'Retry with the same details to check safely. Do not start another transfer.',
            'ഇതേ വിവരങ്ങളോടെ വീണ്ടും പരിശോധിക്കുക. മറ്റൊരു transfer തുടങ്ങരുത്.',
          )
        : switch (outcome.failureCode) {
            'recipient_unavailable' => text(
              'Recipient wallet is unavailable or blocked.',
              'സ്വീകരിക്കുന്ന wallet ലഭ്യമല്ല അല്ലെങ്കിൽ blocked ആണ്.',
            ),
            'recipient_changed' => text(
              'Recipient details changed. Check the wallet number again.',
              'സ്വീകരിക്കുന്നയാളുടെ വിവരങ്ങൾ മാറി. Wallet നമ്പർ വീണ്ടും പരിശോധിക്കുക.',
            ),
            'insufficient_balance' => text(
              'Not enough coins.',
              'ആവശ്യത്തിന് coins ഇല്ല.',
            ),
            'wallet_inactive' => text(
              'Your wallet is inactive. Contact support.',
              'Wallet inactive ആണ്. Support-നെ ബന്ധപ്പെടുക.',
            ),
            'pin_missing' => text(
              'Set your Security PIN in Profile first.',
              'ആദ്യം Profile-ൽ Security PIN സജ്ജമാക്കുക.',
            ),
            'pin_locked' => text(
              'PIN locked. Try again after 15 minutes.',
              'PIN lock ആയി. 15 മിനിറ്റിന് ശേഷം ശ്രമിക്കുക.',
            ),
            'invalid_pin' => text(
              'Incorrect PIN. Check and try again.',
              'PIN തെറ്റാണ്. പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
            ),
            _ =>
              success
                  ? text(
                      'Your coins have been transferred.',
                      'Coins വിജയകരമായി അയച്ചു.',
                    )
                  : text(
                      'Transfer could not be completed.',
                      'Transfer പൂർത്തിയാക്കാൻ കഴിഞ്ഞില്ല.',
                    ),
          };
    final date = outcome.date?.toLocal();
    final formattedDate = date == null
        ? null
        : '${MaterialLocalizations.of(context).formatFullDate(date)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
    return UserPageScaffold(
      identity: unknown
          ? UserPageIdentity.resultUnknown
          : success
          ? UserPageIdentity.resultSuccess
          : UserPageIdentity.resultFailure,
      appBar: AppBar(title: Text(text('Payment details', 'Payment വിവരങ്ങൾ'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: userLine),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: color.withValues(alpha: .12),
                      child: Icon(
                        unknown
                            ? Icons.schedule
                            : success
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        size: 38,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(detail, textAlign: TextAlign.center),
                    const SizedBox(height: 22),
                    const Divider(),
                    _ReceiptRow(
                      label: text('Coins', 'Coins'),
                      value: '${outcome.amount}',
                    ),
                    _ReceiptRow(
                      label: text('Recipient', 'സ്വീകരിക്കുന്നയാൾ'),
                      value: outcome.name.isEmpty
                          ? text('Recipient', 'സ്വീകരിക്കുന്നയാൾ')
                          : outcome.name,
                    ),
                    _ReceiptRow(
                      label: text('Wallet number', 'Wallet നമ്പർ'),
                      value: outcome.wallet,
                    ),
                    if (outcome.reference != null)
                      _ReceiptRow(
                        label: text('Reference ID', 'Reference ID'),
                        value: outcome.reference!,
                      ),
                    if (formattedDate != null)
                      _ReceiptRow(
                        label: text('Date & time', 'തീയതിയും സമയവും'),
                        value: formattedDate,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: Text(
                  unknown
                      ? text(
                          'Retry / check transfer',
                          'Retry / Transfer പരിശോധിക്കുക',
                        )
                      : text('Done', 'പൂർത്തിയായി'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xff71677f))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
