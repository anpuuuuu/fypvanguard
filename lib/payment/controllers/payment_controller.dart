// lib/payment/controllers/payment_controller.dart
// 支付控制器 - 处理支付业务逻辑

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../services/blockchain_service.dart';
import '../services/payment_gateway_service.dart';

/// 支付控制器
class PaymentController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BlockchainService _blockchainService = BlockchainService();
  final PaymentGatewayService _paymentGatewayService = PaymentGatewayService();

  /// 初始化服务
  Future<void> initialize() async {
    await _blockchainService.initialize();
    await _paymentGatewayService.initialize();
  }

  /// 处理区块链支付
  /// [amount] - 支付金额（ETH）
  /// [feeType] - 费用类型
  /// [fromAddress] - 发送地址（从Ganache获取）
  /// [privateKey] - 用户私钥（应该从安全存储中获取）
  /// [toAddress] - 接收地址（管理方地址）
  /// [description] - 支付描述
  Future<Transaction> processBlockchainPayment({
    required double amount,
    required FeeType feeType,
    required String fromAddress,
    required String privateKey,
    required String toAddress,
    String? description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // 获取用户信息
    final accountDoc = await _firestore
        .collection('accounts')
        .doc(user.uid)
        .get();
    final accountData = accountDoc.data();
    final residentId = accountData?['residentId'] as String? ?? user.uid;

    // 创建待处理交易记录
    final transaction = Transaction(
      userId: user.uid,
      residentId: residentId,
      amount: amount,
      feeType: feeType,
      paymentMethod: PaymentMethod.blockchain,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
      toAddress: toAddress,
      description: description,
    );

    // 保存到Firestore
    final docRef = await _firestore
        .collection('transactions')
        .add(transaction.toFirestore());

    try {
      // 更新状态为处理中
      await docRef.update({
        'status': TransactionStatus.processing.toString().split('.').last,
      });

      // 发送区块链交易
      final transactionHash = await _blockchainService.sendTransaction(
        fromAddress: fromAddress,
        privateKey: privateKey,
        toAddress: toAddress,
        amount: amount,
      );

      // 等待交易确认（可选，可以异步处理）
      Map<String, dynamic>? receipt;
      try {
        receipt = await _blockchainService.waitForConfirmation(
          transactionHash,
          maxWaitTime: 30,
        );
      } catch (e) {
        // 如果等待超时，交易可能还在pending，但我们可以记录哈希
        // 实际应用中可以使用后台任务来检查交易状态
      }

      // 更新交易记录
      final updateData = <String, dynamic>{
        'status': TransactionStatus.completed.toString().split('.').last,
        'transactionHash': transactionHash,
        'fromAddress': fromAddress,
        'completedAt': FieldValue.serverTimestamp(),
      };

      if (receipt != null && receipt['blockNumber'] != null) {
        updateData['blockNumber'] = receipt['blockNumber'];
      }

      await docRef.update(updateData);

      // 返回更新后的交易
      final updatedDoc = await docRef.get();
      return Transaction.fromFirestore(updatedDoc);
    } catch (e) {
      // 更新为失败状态
      await docRef.update({
        'status': TransactionStatus.failed.toString().split('.').last,
      });
      throw Exception('Blockchain payment failed: $e');
    }
  }

  /// 处理传统支付（Stripe）
  /// [amount] - 支付金额
  /// [feeType] - 费用类型
  /// [paymentMethodId] - Stripe支付方法ID
  /// [description] - 支付描述
  Future<Transaction> processStripePayment({
    required double amount,
    required FeeType feeType,
    required String paymentMethodId,
    String? description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // 获取用户信息
    final accountDoc = await _firestore
        .collection('accounts')
        .doc(user.uid)
        .get();
    final accountData = accountDoc.data();
    final residentId = accountData?['residentId'] as String? ?? user.uid;

    // 创建支付意图
    final paymentIntent = await _paymentGatewayService.createPaymentIntent(
      amount: amount,
      currency: 'MYR', // 马来西亚林吉特，可根据需要修改
      metadata: {
        'userId': user.uid,
        'residentId': residentId,
        'feeType': feeType.toString().split('.').last,
      },
    );

    final paymentIntentId = paymentIntent['id'] as String;

    // 创建待处理交易记录
    final transaction = Transaction(
      userId: user.uid,
      residentId: residentId,
      amount: amount,
      feeType: feeType,
      paymentMethod: PaymentMethod.stripe,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
      paymentIntentId: paymentIntentId,
      description: description,
    );

    // 保存到Firestore
    final docRef = await _firestore
        .collection('transactions')
        .add(transaction.toFirestore());

    try {
      // 更新状态为处理中
      await docRef.update({
        'status': TransactionStatus.processing.toString().split('.').last,
      });

      // 确认支付
      await _paymentGatewayService.confirmPayment(
        paymentIntentId: paymentIntentId,
        paymentMethodId: paymentMethodId,
      );

      // 获取支付状态
      final paymentStatus = await _paymentGatewayService.getPaymentStatus(
        paymentIntentId,
      );

      final status = paymentStatus['status'] as String;
      final isSucceeded = status == 'succeeded';

      // 更新交易记录
      await docRef.update({
        'status': isSucceeded
            ? TransactionStatus.completed.toString().split('.').last
            : TransactionStatus.failed.toString().split('.').last,
        'receiptId': paymentStatus['charges']?['data']?[0]?['receipt_url'] as String?,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // 返回更新后的交易
      final updatedDoc = await docRef.get();
      return Transaction.fromFirestore(updatedDoc);
    } catch (e) {
      // 更新为失败状态
      await docRef.update({
        'status': TransactionStatus.failed.toString().split('.').last,
      });
      throw Exception('Stripe payment failed: $e');
    }
  }

  /// 获取用户的交易历史
  Stream<List<Transaction>> getTransactionHistory(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Transaction.fromFirestore(doc))
            .toList());
  }

  /// 获取特定交易
  Future<Transaction?> getTransaction(String transactionId) async {
    final doc = await _firestore
        .collection('transactions')
        .doc(transactionId)
        .get();
    
    if (!doc.exists) return null;
    return Transaction.fromFirestore(doc);
  }

  /// 获取待支付费用列表
  /// 这里可以根据业务逻辑查询需要支付的费用
  /// 例如：管理费、滞纳金等
  Future<List<Map<String, dynamic>>> getPendingFees(String residentId) async {
    // 示例：查询管理费配置
    // 实际应用中应该从Firestore查询费用配置
    final fees = <Map<String, dynamic>>[];

    // 检查是否有未支付的管理费
    final managementFee = await _getManagementFee(residentId);
    if (managementFee != null && managementFee['amount'] > 0) {
      fees.add({
        'type': FeeType.managementFee,
        'amount': managementFee['amount'],
        'description': '管理费 - ${managementFee['period']}',
        'dueDate': managementFee['dueDate'],
      });
    }

    // 检查是否有滞纳金
    final lateFees = await _getLateFees(residentId);
    fees.addAll(lateFees);

    return fees;
  }

  /// 获取管理费（示例实现）
  Future<Map<String, dynamic>?> _getManagementFee(String residentId) async {
    // 这里应该从Firestore查询实际的管理费配置
    // 示例实现
    try {
      final residentDoc = await _firestore
          .collection('residents')
          .doc(residentId)
          .get();
      
      final data = residentDoc.data();
      final monthlyFee = data?['monthlyManagementFee'] as double? ?? 0.0;
      
      if (monthlyFee > 0) {
        return {
          'amount': monthlyFee,
          'period': '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
          'dueDate': DateTime.now().add(const Duration(days: 7)),
        };
      }
    } catch (e) {
      // 处理错误
    }
    return null;
  }

  /// 获取滞纳金（示例实现）
  Future<List<Map<String, dynamic>>> _getLateFees(String residentId) async {
    // 这里应该查询实际未支付的费用并计算滞纳金
    // 示例实现
    return [];
  }

  /// 清理资源
  void dispose() {
    _blockchainService.dispose();
  }
}
