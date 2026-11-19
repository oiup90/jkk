import 'user_page_canvas.dart';

import 'package:flutter/material.dart';

import 'support_page.dart';

/// Feature-specific notices. Operator contact/retention/refund terms must be
/// confirmed by the app owner before publishing these as final legal policies.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, this.terms = false});
  final bool terms;
  @override
  Widget build(BuildContext context) {
    String text(String en, String ml) => supportText(context, en, ml);
    final sections = terms
        ? <String, String>{
            text('Using Freelan Space', 'Freelan Space ഉപയോഗം'): text(
              'Use your own account and provide accurate information. Do not impersonate others, submit misleading evidence, spam, or misuse another member’s information.',
              'സ്വന്തം account ഉപയോഗിച്ച് ശരിയായ വിവരങ്ങൾ നൽകുക. മറ്റുള്ളവരെ അനുകരിക്കരുത്; തെറ്റായ തെളിവുകൾ, spam, വിവരങ്ങളുടെ ദുരുപയോഗം എന്നിവ ഒഴിവാക്കുക.',
            ),
            text('Campaigns and reviews', 'Campaigns, reviews'): text(
              'Campaign owners or administrators review submitted evidence. Instagram actions are not automatically verified or guaranteed. Follow Instagram’s rules when using its service. Saved usernames are entered by members and do not prove account ownership.',
              'Campaign ഉടമകളോ administrators-ഓ തെളിവുകൾ പരിശോധിക്കുന്നു. Instagram പ്രവർത്തനങ്ങൾ സ്വയമേവ പരിശോധിക്കുകയോ ഉറപ്പുനൽകുകയോ ചെയ്യുന്നില്ല. Instagram ഉപയോഗിക്കുമ്പോൾ അതിന്റെ നിയമങ്ങൾ പാലിക്കുക. ചേർത്ത usernames account ownership തെളിയിക്കുന്നില്ല.',
            ),
            text('Coins and transfers', 'Coins, transfers'): text(
              'Coins are app credits for campaigns. Creating a campaign reserves coins; cancellation refunds unused campaign coins. Transfers send credits to the wallet number you confirm and cannot be cancelled in the app. Check the recipient and amount before confirming.',
              'Coins campaigns-നുള്ള app credits ആണ്. Campaign തുടങ്ങുമ്പോൾ coins reserve ചെയ്യും; റദ്ദാക്കുമ്പോൾ ഉപയോഗിക്കാത്ത coins തിരികെ ലഭിക്കും. സ്ഥിരീകരിച്ച wallet number-ലേക്കുള്ള transfer app-ൽ റദ്ദാക്കാനാകില്ല. അയയ്ക്കും മുമ്പ് നമ്പറും തുകയും പരിശോധിക്കുക.',
            ),
            text(
              'Purchases and payment help',
              'വാങ്ങലുകളും payment സഹായവും',
            ): text(
              'The checkout shows the purchase price. Coins are credited only after the server verifies payment. For missing coins, disputed transfers or refund requests, use Support and include your order or receipt ID. Do not send passwords, PINs or payment credentials.',
              'Checkout-ൽ വില കാണിക്കും. Server payment സ്ഥിരീകരിച്ച ശേഷമാണ് coins ലഭിക്കുക. Coins ലഭിക്കാത്തതോ transfer/refund പ്രശ്നങ്ങളോ Support-ൽ order/receipt ID സഹിതം അറിയിക്കുക. Password, PIN, payment credentials അയയ്ക്കരുത്.',
            ),
          }
        : <String, String>{
            text(
              'Information used by the app',
              'App ഉപയോഗിക്കുന്ന വിവരങ്ങൾ',
            ): text(
              'The app uses account and profile details, saved Instagram usernames, wallet balances, coin transactions, campaign submissions and screenshots, support messages, and notification preferences. A device push token is registered when notifications are enabled. Photos are provided when you choose to upload them.',
              'Account/profile വിവരങ്ങൾ, Instagram usernames, wallet balance, coin transactions, campaign submissions/screenshots, support messages, notification preferences എന്നിവ app ഉപയോഗിക്കുന്നു. Notifications enable ചെയ്യുമ്പോൾ device push token register ചെയ്യും. നിങ്ങൾ upload ചെയ്യുന്ന photos ആണ് ഉപയോഗിക്കുന്നത്.',
            ),
            text('Who can see information', 'വിവരങ്ങൾ ആർക്കു കാണാം'): text(
              'Campaign information is visible to signed-in members as needed to perform tasks. Submission evidence is available to the submitting member, the campaign owner and administrators. Support conversations are available to you and authorized administrators. Wallet numbers are identifiers you can share to receive coins; they are not login credentials.',
              'Tasks ചെയ്യാൻ ആവശ്യമായ campaign വിവരങ്ങൾ signed-in അംഗങ്ങൾക്ക് കാണാം. Submission തെളിവുകൾ സമർപ്പിച്ച അംഗം, campaign ഉടമ, administrators എന്നിവർക്ക് ലഭിക്കും. Support chat നിങ്ങൾക്കും authorized administrators-നും ലഭിക്കും. Coins സ്വീകരിക്കാൻ wallet number പങ്കിടാം; അത് login credential അല്ല.',
            ),
            text(
              'Services and device storage',
              'Services, device storage',
            ): text(
              'Supabase provides account and app data services; Cloudflare R2 hosts APK downloads; Firebase supports push delivery; Instamojo handles payment checkout. Opening Instagram or checkout uses those services. The app stores preferences locally and uses secure storage when login is saved. Android balance audio is played locally.',
              'Supabase account/app data services നൽകുന്നു; Cloudflare R2 APK downloads host ചെയ്യുന്നു; Firebase push delivery-യും Instamojo payment checkout-ഉം നൽകുന്നു. Instagram/checkout തുറക്കുമ്പോൾ അവയുടെ services ഉപയോഗിക്കുന്നു. Preferences device-ൽ സൂക്ഷിക്കും; saved login secure storage ഉപയോഗിക്കുന്നു. Balance audio device-ലാണ് play ചെയ്യുന്നത്.',
            ),
            text(
              'Your choices and requests',
              'നിങ്ങളുടെ തിരഞ്ഞെടുപ്പുകൾ',
            ): text(
              'Manage notifications, saved login and Instagram usernames in Settings and Profile. Contact Support in Profile for access, correction, deletion or privacy questions. Include only the details needed to identify your request. Never send your password or Security PIN in chat.',
              'Settings/Profile വഴി notifications, saved login, Instagram usernames എന്നിവ നിയന്ത്രിക്കാം. Data access, correction, deletion, privacy ചോദ്യങ്ങൾക്ക് Profile-ലെ Support ഉപയോഗിക്കുക. ആവശ്യമായ വിവരങ്ങൾ മാത്രം നൽകുക. Password/Security PIN chat-ൽ അയയ്ക്കരുത്.',
            ),
          };
    return UserPageScaffold(
      identity: terms ? UserPageIdentity.terms : UserPageIdentity.privacy,
      appBar: AppBar(
        title: Text(
          terms
              ? text('Terms of Service', 'സേവന നിബന്ധനകൾ')
              : text('Privacy Policy', 'സ്വകാര്യതാ നയം'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: terms
                        ? const Color(0xffffefd8)
                        : const Color(0xffe1eff6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    terms ? Icons.article_outlined : Icons.privacy_tip_outlined,
                    color: terms
                        ? const Color(0xff926018)
                        : const Color(0xff326b7e),
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              for (final (index, section) in sections.entries.indexed)
                Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(index + 1).toString().padLeft(2, '0')}  ${section.key}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        SelectableText(section.value),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      for (final terms in [false, true])
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => LegalPage(terms: terms)),
          ),
          child: Text(
            supportText(
              context,
              terms ? 'Terms of Service' : 'Privacy Policy',
              terms ? 'സേവന നിബന്ധനകൾ' : 'സ്വകാര്യതാ നയം',
            ),
          ),
        ),
    ],
  );
}
