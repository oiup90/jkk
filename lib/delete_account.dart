import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_saved_login.dart';
import 'user_localization.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({
    super.key,
    required this.client,
    required this.savedLogin,
  });
  final SupabaseClient client;
  final UserSavedLogin savedLogin;
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final code = TextEditingController();
  bool busy = false, sent = false;
  String? message;
  DateTime? sentAt;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> run(bool deleting) async {
    if (busy) return;
    if (deleting && !RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(() => message = 'Enter the six-digit email code.');
      return;
    }
    if (!deleting &&
        sentAt != null &&
        DateTime.now().difference(sentAt!).inSeconds < 60) {
      setState(
        () => message = 'Wait 60 seconds before requesting another code.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (!deleting) {
        await widget.client.auth.reauthenticate();
        if (mounted) {
          setState(() {
            sent = true;
            sentAt = DateTime.now();
            message = 'Check your email for the confirmation code.';
          });
        }
      } else {
        final result = await widget.client.rpc(
          'delete_my_account',
          params: {'p_nonce': code.text.trim()},
        );
        if (result != 'ok') {
          if (mounted) {
            setState(
              () => message = result == 'admin_account'
                  ? 'Administrator accounts must be managed by the project owner.'
                  : 'Code invalid or expired. Request a new code.',
            );
          }
          return;
        }
        // Account deletion has succeeded even if device cleanup fails.
        try {
          await widget.savedLogin.forget();
        } catch (_) {
          /* Retry clearing through the sign-in forget control. */
        }
        try {
          await widget.client.auth.signOut(scope: SignOutScope.local);
        } catch (_) {
          /* Deleted session cannot access server data. */
        }
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Unable to continue. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        userText(
          context,
          'Permanently delete account',
          'Account സ്ഥിരമായി നീക്കുക',
        ),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              userText(
                context,
                'Your account and login access will be permanently removed and coins forfeited. Administrators retain a separate archive of your profile and app activity for audit, including campaigns, evidence, wallet history and support messages. Passwords and login tokens are not archived. This cannot be undone.',
                'Account-ഉം login access-ഉം സ്ഥിരമായി നീങ്ങും; coins നഷ്ടമാകും. Profile, campaigns, evidence, wallet history, support messages തുടങ്ങിയ app വിവരങ്ങൾ admin audit archive-ൽ നിലനിർത്തും. Password, login tokens സൂക്ഷിക്കില്ല. ഇത് തിരിച്ചെടുക്കാനാവില്ല.',
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: busy ? null : () => run(false),
              child: Text(
                sent ? 'Resend email code' : 'Send confirmation code',
              ),
            ),
            if (sent) ...[
              TextField(
                controller: code,
                enabled: !busy,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Email confirmation code',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                ),
                onPressed: busy ? null : () => run(true),
                child: Text(
                  userText(
                    context,
                    'Delete my account permanently',
                    'എന്റെ account സ്ഥിരമായി നീക്കുക',
                  ),
                ),
              ),
            ],
            if (message != null) Text(message!),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
  );
}
