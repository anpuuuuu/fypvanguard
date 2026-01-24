// lib/payment/services/payment_gateway_service.dart
// Traditional payment gateway service - Stripe integration (simplified version)

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Payment gateway service
/// Uses Stripe as traditional payment method
/// Note: This is a simplified implementation, production environment requires backend API support
class PaymentGatewayService {
  // Note: In production environment, these should be retrieved from environment variables or secure configuration
  // Here using test keys, need to replace with your Stripe keys in actual use
  static const String _stripePublishableKey = 'pk_test_your_publishable_key';
  static const String _stripeSecretKey = 'sk_test_your_secret_key';
  static const String _stripeApiUrl = 'https://api.stripe.com/v1';

  bool _initialized = false;

  /// Initialize Stripe
  Future<void> initialize() async {
    if (_initialized) return;
    
    // Note: In actual applications, Stripe initialization should be completed at app startup
    // Here only marks as initialized
    _initialized = true;
  }

  /// Create payment intent (via backend API)
  /// Note: This is a virtual payment - always returns success for testing
  /// In production, should call your backend API to create payment intent
  Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String currency,
    Map<String, dynamic>? metadata,
  }) async {
    // Virtual payment - always return success
    // In production, this would call the actual Stripe API or your backend
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate API call
    
    return {
      'id': 'pi_virtual_${DateTime.now().millisecondsSinceEpoch}',
      'client_secret': 'pi_virtual_secret_${DateTime.now().millisecondsSinceEpoch}',
      'status': 'requires_payment_method',
      'amount': (amount * 100).toInt(),
      'currency': currency.toLowerCase(),
    };
  }

  /// Confirm payment
  /// [paymentIntentId] - Payment intent ID
  /// [paymentMethodId] - Payment method ID (collected from Stripe)
  /// Note: This is a virtual payment - always returns success for testing
  Future<Map<String, dynamic>> confirmPayment({
    required String paymentIntentId,
    required String paymentMethodId,
  }) async {
    // Virtual payment - always return success
    // In production, this would call the actual Stripe API
    await Future.delayed(const Duration(seconds: 1)); // Simulate processing time
    
    return {
      'id': paymentIntentId,
      'status': 'succeeded',
      'charges': {
        'data': [
          {
            'id': 'ch_virtual_${DateTime.now().millisecondsSinceEpoch}',
            'status': 'succeeded',
            'receipt_url': 'https://pay.stripe.com/receipts/virtual_$paymentIntentId',
            'amount': 0, // Virtual payment
            'currency': 'myr',
          }
        ]
      }
    };
  }

  /// Get payment status
  /// Note: This is a virtual payment - always returns succeeded status
  Future<Map<String, dynamic>> getPaymentStatus(String paymentIntentId) async {
    // Virtual payment - always return succeeded
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate API call
    
    return {
      'id': paymentIntentId,
      'status': 'succeeded',
      'charges': {
        'data': [
          {
            'id': 'ch_virtual_${DateTime.now().millisecondsSinceEpoch}',
            'status': 'succeeded',
            'receipt_url': 'https://pay.stripe.com/receipts/virtual_$paymentIntentId',
            'amount': 0, // Virtual payment
            'currency': 'myr',
          }
        ]
      }
    };
  }

  /// Create refund
  /// [paymentIntentId] - Payment intent ID
  /// [amount] - Refund amount (optional, if not provided then full refund)
  Future<Map<String, dynamic>> createRefund({
    required String paymentIntentId,
    double? amount,
  }) async {
    try {
      final body = <String, String>{
        'payment_intent': paymentIntentId,
      };
      
      if (amount != null) {
        body['amount'] = (amount * 100).toInt().toString();
      }

      final response = await http.post(
        Uri.parse('$_stripeApiUrl/refunds'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to create refund: ${response.body}');
      }
    } catch (e) {
      throw Exception('Refund creation failed: $e');
    }
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
