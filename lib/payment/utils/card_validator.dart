// lib/payment/utils/card_validator.dart
// Card validation for PayPal Sandbox - Luhn check and format validation

/// Luhn algorithm check for card number validity
bool luhnCheck(String cardNumber) {
  final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 13 || digits.length > 19) return false;

  int sum = 0;
  bool alternate = false;
  for (int i = digits.length - 1; i >= 0; i--) {
    int n = int.tryParse(digits[i]) ?? 0;
    if (alternate) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alternate = !alternate;
  }
  return sum % 10 == 0;
}

/// Validate card number (length + Luhn)
bool isValidCardNumber(String? value) {
  if (value == null || value.isEmpty) return false;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 13 && digits.length <= 19 && luhnCheck(digits);
}

/// Validate expiry: MM and YYYY must be future
bool isValidExpiry(int month, int year) {
  if (month < 1 || month > 12) return false;
  final now = DateTime.now();
  if (year < now.year) return false;
  if (year == now.year && month < now.month) return false;
  return true;
}

/// Validate CVV (3 or 4 digits)
bool isValidCvv(String? value) {
  if (value == null || value.isEmpty) return false;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length == 3 || digits.length == 4;
}
