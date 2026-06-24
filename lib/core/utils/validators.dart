/// Form field validators. Each returns `null` when valid, or an error
/// message string when invalid — matching the [FormFieldValidator] contract.
class Validators {
  Validators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$',
  );

  // Malaysian mobile numbers, with or without country code, e.g.
  // 0123456789, +60123456789, 60123456789.
  static final RegExp _phoneRegExp = RegExp(r'^(\+?6?0)[0-9]{8,10}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailRegExp.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? phone(String? value) {
    final v = value?.replaceAll(RegExp(r'[\s-]'), '').trim() ?? '';
    if (v.isEmpty) return 'Phone number is required';
    if (!_phoneRegExp.hasMatch(v)) return 'Enter a valid phone number';
    return null;
  }

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  /// Validates a price entered in Ringgit (e.g. "7.50"). Returns null when
  /// the value parses to a positive amount.
  static String? price(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Price is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid price';
    if (parsed <= 0) return 'Price must be greater than zero';
    return null;
  }
}
