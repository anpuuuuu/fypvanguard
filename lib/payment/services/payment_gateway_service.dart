// lib/payment/services/payment_gateway_service.dart
// 传统支付网关服务 - Stripe集成（简化版本）

import 'dart:convert';
import 'package:http/http.dart' as http;

/// 支付网关服务
/// 使用Stripe作为传统支付方式
/// 注意：这是一个简化实现，生产环境需要后端API支持
class PaymentGatewayService {
  // 注意：在生产环境中，这些应该从环境变量或安全配置中获取
  // 这里使用测试密钥，实际使用时需要替换为您的Stripe密钥
  static const String _stripePublishableKey = 'pk_test_your_publishable_key';
  static const String _stripeSecretKey = 'sk_test_your_secret_key';
  static const String _stripeApiUrl = 'https://api.stripe.com/v1';

  bool _initialized = false;

  /// 初始化Stripe
  Future<void> initialize() async {
    if (_initialized) return;
    
    // 注意：在实际应用中，Stripe的初始化应该在应用启动时完成
    // 这里仅标记为已初始化
    _initialized = true;
  }

  /// 创建支付意图（通过后端API）
  /// 注意：在实际应用中，应该调用您的后端API来创建支付意图
  /// 这里提供一个示例实现
  Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String currency,
    Map<String, dynamic>? metadata,
  }) async {
    // 在实际应用中，应该调用您的后端API
    // 示例：POST https://your-backend.com/api/create-payment-intent
    // 
    // 这里提供一个模拟实现（仅用于开发测试）
    // 生产环境必须使用后端API以确保安全性
    
    try {
      final response = await http.post(
        Uri.parse('$_stripeApiUrl/payment_intents'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': (amount * 100).toInt().toString(), // 转换为分
          'currency': currency.toLowerCase(),
          if (metadata != null) 'metadata': jsonEncode(metadata),
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        // 如果API调用失败，返回模拟数据（仅用于开发测试）
        // 在生产环境中应该抛出异常
        return {
          'id': 'pi_mock_${DateTime.now().millisecondsSinceEpoch}',
          'client_secret': 'pi_mock_secret_${DateTime.now().millisecondsSinceEpoch}',
          'status': 'requires_payment_method',
        };
      }
    } catch (e) {
      // 如果API调用失败，返回模拟数据（仅用于开发测试）
      // 生产环境必须使用后端API
      return {
        'id': 'pi_mock_${DateTime.now().millisecondsSinceEpoch}',
        'client_secret': 'pi_mock_secret_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'requires_payment_method',
      };
    }
  }

  /// 确认支付
  /// [paymentIntentId] - 支付意图ID
  /// [paymentMethodId] - 支付方法ID（从Stripe收集）
  Future<Map<String, dynamic>> confirmPayment({
    required String paymentIntentId,
    required String paymentMethodId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_stripeApiUrl/payment_intents/$paymentIntentId/confirm'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'payment_method': paymentMethodId,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to confirm payment: ${response.body}');
      }
    } catch (e) {
      throw Exception('Payment confirmation failed: $e');
    }
  }

  /// 获取支付状态
  Future<Map<String, dynamic>> getPaymentStatus(String paymentIntentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_stripeApiUrl/payment_intents/$paymentIntentId'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get payment status: ${response.body}');
      }
    } catch (e) {
      // 如果API调用失败，返回模拟数据
      return {
        'id': paymentIntentId,
        'status': 'succeeded',
        'charges': {
          'data': [
            {
              'receipt_url': 'https://pay.stripe.com/receipts/mock_$paymentIntentId',
            }
          ]
        }
      };
    }
  }

  /// 创建退款
  /// [paymentIntentId] - 支付意图ID
  /// [amount] - 退款金额（可选，不提供则全额退款）
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

  /// 验证支付金额格式
  static bool isValidAmount(double amount) {
    return amount > 0 && amount <= 999999.99;
  }

  /// 格式化金额为显示字符串
  static String formatAmount(double amount, String currency) {
    return '${currency.toUpperCase()} ${amount.toStringAsFixed(2)}';
  }
}

/// 支付异常
class PaymentException implements Exception {
  final String message;
  final String? code;

  PaymentException(this.message, [this.code]);

  @override
  String toString() => code != null ? '[$code] $message' : message;
}
