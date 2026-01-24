// lib/payment/models/transaction_model.dart
// 交易数据模型

import 'package:cloud_firestore/cloud_firestore.dart';

/// 支付方法枚举
enum PaymentMethod {
  blockchain, // 区块链支付
  stripe,    // Stripe支付
  paypal,    // PayPal支付（预留）
}

/// 交易状态枚举
enum TransactionStatus {
  pending,   // 待处理
  processing, // 处理中
  completed, // 已完成
  failed,    // 失败
  cancelled, // 已取消
}

/// 费用类型枚举
enum FeeType {
  managementFee,  // 管理费
  maintenanceFee, // 维护费
  lateFee,        // 滞纳金
  other,          // 其他
}

/// 交易模型
class Transaction {
  final String? id;
  final String userId;
  final String residentId;
  final double amount;
  final FeeType feeType;
  final PaymentMethod paymentMethod;
  final TransactionStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  
  // 区块链相关字段
  final String? transactionHash; // 区块链交易哈希
  final String? fromAddress;      // 发送地址
  final String? toAddress;         // 接收地址
  final int? blockNumber;         // 区块号
  
  // 传统支付相关字段
  final String? receiptId;        // Stripe收据ID
  final String? paymentIntentId;   // Stripe支付意图ID
  
  // 元数据
  final String? description;
  final Map<String, dynamic>? metadata;

  Transaction({
    this.id,
    required this.userId,
    required this.residentId,
    required this.amount,
    required this.feeType,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.transactionHash,
    this.fromAddress,
    this.toAddress,
    this.blockNumber,
    this.receiptId,
    this.paymentIntentId,
    this.description,
    this.metadata,
  });

  /// 从Firestore文档创建Transaction对象
  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Transaction(
      id: doc.id,
      userId: data['userId'] as String,
      residentId: data['residentId'] as String,
      amount: (data['amount'] as num).toDouble(),
      feeType: FeeType.values.firstWhere(
        (e) => e.toString().split('.').last == data['feeType'],
        orElse: () => FeeType.other,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString().split('.').last == data['paymentMethod'],
        orElse: () => PaymentMethod.stripe,
      ),
      status: TransactionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => TransactionStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      transactionHash: data['transactionHash'] as String?,
      fromAddress: data['fromAddress'] as String?,
      toAddress: data['toAddress'] as String?,
      blockNumber: data['blockNumber'] as int?,
      receiptId: data['receiptId'] as String?,
      paymentIntentId: data['paymentIntentId'] as String?,
      description: data['description'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// 转换为Firestore文档数据
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'residentId': residentId,
      'amount': amount,
      'feeType': feeType.toString().split('.').last,
      'paymentMethod': paymentMethod.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (transactionHash != null) 'transactionHash': transactionHash,
      if (fromAddress != null) 'fromAddress': fromAddress,
      if (toAddress != null) 'toAddress': toAddress,
      if (blockNumber != null) 'blockNumber': blockNumber,
      if (receiptId != null) 'receiptId': receiptId,
      if (paymentIntentId != null) 'paymentIntentId': paymentIntentId,
      if (description != null) 'description': description,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// 获取费用类型显示名称
  String get feeTypeDisplayName {
    switch (feeType) {
      case FeeType.managementFee:
        return '管理费';
      case FeeType.maintenanceFee:
        return '维护费';
      case FeeType.lateFee:
        return '滞纳金';
      case FeeType.other:
        return '其他费用';
    }
  }

  /// 获取支付方法显示名称
  String get paymentMethodDisplayName {
    switch (paymentMethod) {
      case PaymentMethod.blockchain:
        return '区块链支付';
      case PaymentMethod.stripe:
        return '信用卡/借记卡';
      case PaymentMethod.paypal:
        return 'PayPal';
    }
  }

  /// 获取状态显示名称
  String get statusDisplayName {
    switch (status) {
      case TransactionStatus.pending:
        return '待处理';
      case TransactionStatus.processing:
        return '处理中';
      case TransactionStatus.completed:
        return '已完成';
      case TransactionStatus.failed:
        return '失败';
      case TransactionStatus.cancelled:
        return '已取消';
    }
  }

  /// 复制并更新字段
  Transaction copyWith({
    String? id,
    String? userId,
    String? residentId,
    double? amount,
    FeeType? feeType,
    PaymentMethod? paymentMethod,
    TransactionStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? transactionHash,
    String? fromAddress,
    String? toAddress,
    int? blockNumber,
    String? receiptId,
    String? paymentIntentId,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      residentId: residentId ?? this.residentId,
      amount: amount ?? this.amount,
      feeType: feeType ?? this.feeType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      transactionHash: transactionHash ?? this.transactionHash,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      blockNumber: blockNumber ?? this.blockNumber,
      receiptId: receiptId ?? this.receiptId,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
    );
  }
}
