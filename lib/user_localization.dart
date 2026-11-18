import 'package:flutter/widgets.dart';

import 'user_translations.dart';

/// User-facing text is resolved locally; no account or message data leaves the device.
String userText(
  BuildContext context,
  String english,
  String malayalam, {
  bool forceMalayalam = false,
}) {
  final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
  if (forceMalayalam || code == 'ml') return malayalam;
  return userTranslations[code]?[english] ?? english;
}

String userTransferConfirmation(
  BuildContext context, {
  required String amount,
  required String name,
  required String wallet,
}) {
  // Isolate identifiers so the ordering stays clear in RTL text.
  final person = '\u2068$name\u2069',
      number = '\u2068$wallet\u2069',
      coins = '\u2068$amount\u2069';
  return switch (Localizations.localeOf(context).languageCode) {
    'hi' =>
      '$person ($number) को $coins कॉइन भेजें? प्राप्तकर्ता और राशि जाँचें। ट्रांसफ़र रद्द नहीं किया जा सकता।',
    'ta' =>
      '$person ($number) க்கு $coins காயின்களை அனுப்பவா? பெறுநரையும் தொகையையும் சரிபார்க்கவும். பரிமாற்றத்தை ரத்துசெய்ய முடியாது.',
    'ar' =>
      'إرسال $coins عملة إلى $person ($number)؟ تحقق من المستلم والمبلغ. لا يمكن إلغاء التحويل.',
    'ml' =>
      '$person ($number) എന്ന വാലറ്റിലേക്ക് $coins coins അയയ്ക്കണോ? പേരും നമ്പറും പരിശോധിക്കുക. Transfer റദ്ദാക്കാനാകില്ല.',
    _ =>
      'Send $coins coins to $person ($number)? Check the recipient and amount. Transfers cannot be cancelled.',
  };
}

String userCodeSentTo(BuildContext context, String address) {
  final value = '\u2068$address\u2069';
  return switch (Localizations.localeOf(context).languageCode) {
    'hi' => '$value पर भेजा गया कोड दर्ज करें।',
    'ta' => '$value க்கு அனுப்பப்பட்ட குறியீட்டை உள்ளிடவும்.',
    'ar' => 'أدخل الرمز المرسل إلى $value.',
    'ml' => '$value-ലേക്ക് ലഭിച്ച code നൽകുക.',
    _ => 'Enter the code sent to $value.',
  };
}
