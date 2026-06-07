class SignupValidators {
  SignupValidators._();

  static const int passengerMinimumAge = 13;
  static const int driverMinimumAge = 18;
  static const int maximumAge = 100;

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _hasLetter = RegExp(r'[A-Za-z]');
  static final RegExp _hasNumber = RegExp(r'\d');
  static final RegExp _hasWhitespace = RegExp(r'\s');

  static String? email(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Email is required';
    }

    if (!_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  static String? name(String? value, {required String fieldName}) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return '$fieldName is required';
    }

    if (name.length < 2) {
      return '$fieldName must be at least 2 characters';
    }

    if (_hasNumber.hasMatch(name)) {
      return '$fieldName cannot contain numbers';
    }

    return null;
  }

  static String? accountFirstName(String? value) {
    final error = name(value, fieldName: 'First name');
    if (error != null) {
      return error;
    }

    if (isReservedAdminName(value)) {
      return 'The name admin is reserved.';
    }

    return null;
  }

  static bool isReservedAdminName(String? value) {
    return (value ?? '').trim().toLowerCase() == 'admin';
  }

  static String? age(
    String? value, {
    required int minimumAge,
    int maximumAge = SignupValidators.maximumAge,
  }) {
    final rawAge = value?.trim() ?? '';

    if (rawAge.isEmpty) {
      return 'Age is required';
    }

    final age = int.tryParse(rawAge);
    if (age == null) {
      return 'Enter a valid age';
    }

    if (age < minimumAge) {
      return 'Must be at least $minimumAge years old';
    }

    if (age > maximumAge) {
      return 'Enter an age below $maximumAge';
    }

    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (_hasWhitespace.hasMatch(password)) {
      return 'Password cannot contain spaces';
    }

    if (!_hasLetter.hasMatch(password) || !_hasNumber.hasMatch(password)) {
      return 'Use letters and at least one number';
    }

    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }
}
