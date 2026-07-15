class AuthFormValidators {
  const AuthFormValidators._();

  static final RegExp _emailPattern = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
  );
  static final RegExp _phonePattern = RegExp(r'^\d{10}$');

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email is required.';
    }

    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }

    if (trimmed.length > 256) {
      return 'Email must be 256 characters or fewer.';
    }

    return null;
  }

  static String? password(String? value, {bool strong = false}) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required.';
    }

    if (password.length > 100) {
      return 'Password must be 100 characters or fewer.';
    }

    if (!strong) {
      return null;
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    if (!RegExp('[A-Z]').hasMatch(password)) {
      return 'Password must contain an uppercase letter.';
    }

    if (!RegExp('[a-z]').hasMatch(password)) {
      return 'Password must contain a lowercase letter.';
    }

    if (!RegExp('[0-9]').hasMatch(password)) {
      return 'Password must contain a number.';
    }

    return null;
  }

  static String? fullName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Full name is required.';
    }

    if (trimmed.length < 2) {
      return 'Full name must be at least 2 characters.';
    }

    if (trimmed.length > 200) {
      return 'Full name must be 200 characters or fewer.';
    }

    return null;
  }

  static String? phoneNumber(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }

    if (!_phonePattern.hasMatch(trimmed)) {
      return 'Phone number must contain exactly 10 digits.';
    }

    return null;
  }
}
