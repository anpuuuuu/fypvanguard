// lib/payment/services/payment_gateway_service.dart
// PayPal Sandbox payment gateway - simulated, no real money deducted

/// Payment gateway service - PayPal Sandbox (simulated).
/// All valid card formats are accepted; no real charge is made.
/// Simulates create order -> capture flow and always returns success.
class PaymentGatewayService {
  bool _initialized = false;

  /// Initialize PayPal Sandbox (simulated - no real API keys required for demo)
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Create order (simulated) - no real API call, just loading simulation
  Future<Map<String, dynamic>> createOrder({
    required double amount,
    required String currency,
    Map<String, dynamic>? metadata,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final orderId = 'PAYPAL_${DateTime.now().millisecondsSinceEpoch}';
    return {
      'id': orderId,
      'status': 'CREATED',
      'amount': amount,
      'currency': currency.toLowerCase(),
      'metadata': metadata,
    };
  }

  /// Capture / confirm payment (simulated) - valid card always succeeds
  Future<Map<String, dynamic>> captureOrder({
    required String orderId,
    required String paymentMethodId,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return {
      'id': orderId,
      'status': 'COMPLETED',
      'captureId': 'CAP_${DateTime.now().millisecondsSinceEpoch}',
      'receipt_url':
          'https://www.sandbox.paypal.com/receipt/order/$orderId',
    };
  }

  /// Get payment status (simulated - always completed for sandbox)
  Future<Map<String, dynamic>> getPaymentStatus(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'id': orderId,
      'status': 'COMPLETED',
      'captureId': 'CAP_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
      'receipt_url': 'https://www.sandbox.paypal.com/receipt/order/$orderId',
    };
  }

  /// Validate payment amount format
  static bool isValidAmount(double amount) {
    return amount > 0 && amount <= 999999.99;
  }

  /// Format amount as display string
  static String formatAmount(double amount, String currency) {
    return '${currency.toUpperCase()} ${amount.toStringAsFixed(2)}';
  }
}

/// Payment exception
class PaymentException implements Exception {
  final String message;
  final String? code;

  PaymentException(this.message, [this.code]);

  @override
  String toString() => code != null ? '[$code] $message' : message;
}
