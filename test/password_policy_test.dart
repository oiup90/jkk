import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/password_policy.dart';

void main() {
  test('new passwords need length and all four character groups', () {
    expect(meetsPasswordPolicy('Aa1!short'), isFalse);
    expect(meetsPasswordPolicy('lowercase123!'), isFalse);
    expect(meetsPasswordPolicy('UPPERCASE123!'), isFalse);
    expect(meetsPasswordPolicy('NoNumberHere!'), isFalse);
    expect(meetsPasswordPolicy('NoSymbols1234'), isFalse);
    expect(meetsPasswordPolicy('Abcdefgh12 €'), isFalse);
    expect(meetsPasswordPolicy('Abcdefgh12!X'), isTrue);
    expect(meetsPasswordPolicy('Abcdefgh12\\X'), isTrue);
    expect(meetsPasswordPolicy('Aa1!😀😀😀😀😀😀😀'), isFalse);
    expect(meetsPasswordPolicy('Aa1!😀😀😀😀😀😀😀😀'), isTrue);
    expect(meetsPasswordPolicy('Aa1!${'a' * 68}'), isTrue);
    expect(meetsPasswordPolicy('Aa1!${'a' * 69}'), isFalse);
  });
}
