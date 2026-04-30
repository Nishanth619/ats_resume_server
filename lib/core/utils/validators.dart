class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Minimum 6 characters';
    return null;
  }

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? url(String? value) {
    if (value == null || value.isEmpty) return null; // optional
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return 'Enter a valid URL';
    return null;
  }

  static String? linkedIn(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!value.contains('linkedin.com/in/')) {
      return 'Enter a valid LinkedIn URL (linkedin.com/in/yourname)';
    }
    return null;
  }
}
