import 'package:fitfuel/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth Form Validators Tests', () {
    test('Email validation - valid emails pass', () {
      expect(Validators.validateEmail('user@example.com'), null);
      expect(Validators.validateEmail('test.fitfuel@domain.co'), null);
    });

    test('Email validation - invalid emails return error message', () {
      expect(Validators.validateEmail(''), 'Email address is required');
      expect(Validators.validateEmail(null), 'Email address is required');
      expect(Validators.validateEmail('invalid-email'), 'Please enter a valid email address');
      expect(Validators.validateEmail('user@'), 'Please enter a valid email address');
    });

    test('Password validation - valid passwords pass', () {
      expect(Validators.validatePassword('Password123!'), null);
      expect(Validators.validatePassword('8characters'), null);
    });

    test('Password validation - weak/short passwords return error message', () {
      expect(Validators.validatePassword(''), 'Password is required');
      expect(Validators.validatePassword(null), 'Password is required');
      expect(Validators.validatePassword('short'), 'Password must be at least 8 characters long');
    });

    test('Name validation - valid names pass', () {
      expect(Validators.validateName('FitFuel User'), null);
    });

    test('Name validation - empty name returns error message', () {
      expect(Validators.validateName(''), 'Full name is required');
      expect(Validators.validateName(null), 'Full name is required');
    });
  });
}
