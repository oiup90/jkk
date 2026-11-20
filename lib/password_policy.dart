import 'dart:convert';
import 'dart:math';

// Match Supabase Auth's letters/digits/symbols option for new passwords.
const passwordMinimumLength = 12;
const passwordSymbols = r'''!@#$%^&*()_+-=[]{};'\:"|<>?,./`~''';
const passwordRequirementsEnglish =
    'Use at least 12 characters (up to 72 UTF-8 bytes), including uppercase and lowercase letters, a number and a symbol.';
const passwordRequirementsMalayalam =
    'കുറഞ്ഞത് 12 അക്ഷരങ്ങളും (പരമാവധി 72 UTF-8 bytes) വലിയതും ചെറിയതുമായ ഇംഗ്ലീഷ് അക്ഷരങ്ങളും ഒരു അക്കവും ഒരു ചിഹ്നവും ഉപയോഗിക്കുക.';

bool meetsPasswordPolicy(String password) =>
    password.runes.length >= passwordMinimumLength &&
    utf8.encode(password).length <= 72 &&
    RegExp(r'[A-Z]').hasMatch(password) &&
    RegExp(r'[a-z]').hasMatch(password) &&
    RegExp(r'[0-9]').hasMatch(password) &&
    password.runes.any(
      (rune) => passwordSymbols.contains(String.fromCharCode(rune)),
    );

String generateStrongPassword() {
  final random = Random.secure();
  const groups = [
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    'abcdefghijklmnopqrstuvwxyz',
    '0123456789',
    '!@#%*+-=?',
  ];
  final chars = [
    for (final group in groups) group[random.nextInt(group.length)],
  ];
  final all = groups.join();
  while (chars.length < 20) {
    chars.add(all[random.nextInt(all.length)]);
  }
  chars.shuffle(random);
  return chars.join();
}
