class Validators {
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (!RegExp(r'^[0-9]{9,15}$').hasMatch(value)) {
      return 'Invalid phone number';
    }
    return null;
  }
}