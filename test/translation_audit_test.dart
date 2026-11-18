import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/user_translations.dart';

void main() {
  test('translations contain no unsupported character placeholders', () {
    for (final language in userTranslations.entries) {
      for (final entry in language.value.entries) {
        expect(
          entry.value,
          isNot(contains('⁇')),
          reason: '${language.key}: ${entry.key}',
        );
        expect(
          entry.value,
          isNot(contains('\uFFFD')),
          reason: '${language.key}: ${entry.key}',
        );
      }
    }
  });
  test(
    'payment, task actions and email examples use the corrected meaning',
    () {
      expect(userTranslations['ar']!['Check payment'], 'التحقق من الدفع');
      expect(userTranslations['ta']!['Check payment'], 'கட்டணத்தைச் சரிபார்');
      expect(userTranslations['hi']!['like tasks'], 'लाइक करने के कार्य');
      expect(userTranslations['ta']!['like tasks'], 'லைக் செய்யும் பணிகள்');
      expect(userTranslations['ar']!['like tasks'], 'مهام الإعجاب');
      expect(userTranslations['ar']!['you@example.com'], 'you@example.com');
      expect(userTranslations['ta']!['Sign out'], 'வெளியேறு');
    },
  );
}
