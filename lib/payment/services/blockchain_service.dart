// lib/payment/services/blockchain_service.dart
// 区块链支付服务 - 使用Ganache测试网络
// 使用HTTP直接调用RPC，不依赖web3dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// 区块链支付服务
/// 连接到Ganache测试网络进行以太坊交易
class BlockchainService {
  // Ganache配置（从截图获取）
  static const String rpcUrl = 'http://0.0.0.0:7545';
  static const int chainId = 5777; // Network ID
  static const String networkName = 'Ganache Local';
  
  bool _initialized = false;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// 调用RPC方法
  Future<Map<String, dynamic>> _callRpc(String method, List<dynamic> params) async {
    try {
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': method,
          'params': params,
          'id': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('error')) {
          throw Exception('RPC Error: ${data['error']}');
        }
        return data['result'] as Map<String, dynamic>;
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('RPC call failed: $e');
    }
  }

  /// 获取账户余额（ETH）
  Future<String> getBalance(String address) async {
    if (!_initialized) await initialize();
    final result = await _callRpc('eth_getBalance', [address, 'latest']);
    final balanceHex = result as String;
    // 转换为ETH（从Wei）
    final balanceWei = BigInt.parse(balanceHex.substring(2), radix: 16);
    final balanceEth = balanceWei / BigInt.from(1e18.toInt());
    return balanceEth.toString();
  }

  /// 获取当前Gas价格
  Future<String> getGasPrice() async {
    if (!_initialized) await initialize();
    final result = await _callRpc('eth_gasPrice', []);
    return result as String;
  }

  /// 获取交易计数（nonce）
  Future<int> getTransactionCount(String address) async {
    if (!_initialized) await initialize();
    final result = await _callRpc('eth_getTransactionCount', [address, 'latest']);
    final countHex = result as String;
    return int.parse(countHex.substring(2), radix: 16);
  }

  /// 发送ETH交易
  /// [fromAddress] - 发送方地址（从Ganache获取）
  /// [privateKey] - 发送方私钥（十六进制字符串，不带0x前缀）
  /// [toAddress] - 接收方地址
  /// [amount] - 金额（ETH）
  /// [gasLimit] - Gas限制（可选，默认21000）
  /// 
  /// 返回交易哈希
  Future<String> sendTransaction({
    required String fromAddress,
    required String privateKey,
    required String toAddress,
    required double amount,
    int? gasLimit,
  }) async {
    if (!_initialized) await initialize();

    try {
      // 验证发送地址
      if (!isValidAddress(fromAddress)) {
        throw Exception('Invalid sender address');
      }
      
      // 验证接收地址
      if (!isValidAddress(toAddress)) {
        throw Exception('Invalid recipient address');
      }
      
      // 转换金额为Wei（十六进制）
      final amountWei = BigInt.from((amount * 1e18).toInt());
      final amountHex = '0x${amountWei.toRadixString(16)}';

      // 获取Gas价格
      final gasPriceHex = await getGasPrice();
      
      // 获取nonce
      final nonce = await getTransactionCount(fromAddress);
      final nonceHex = '0x${nonce.toRadixString(16)}';

      // 构建交易对象
      // 注意：Ganache允许直接发送交易，账户会自动解锁
      final transaction = {
        'from': fromAddress,
        'to': toAddress,
        'value': amountHex,
        'gas': '0x${(gasLimit ?? 21000).toRadixString(16)}',
        'gasPrice': gasPriceHex,
        'nonce': nonceHex,
      };

      // Ganache支持直接发送交易（账户自动解锁）
      // 在生产环境中，应该使用eth_signTransaction + eth_sendRawTransaction
      final result = await _callRpc('eth_sendTransaction', [transaction]);
      
      return result as String;
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }

  /// 等待交易确认
  /// [transactionHash] - 交易哈希
  /// [maxWaitTime] - 最大等待时间（秒），默认60秒
  /// 
  /// 返回交易收据，包含区块号等信息
  Future<Map<String, dynamic>?> waitForConfirmation(
    String transactionHash, {
    int maxWaitTime = 60,
  }) async {
    if (!_initialized) await initialize();

    final startTime = DateTime.now();
    
    while (DateTime.now().difference(startTime).inSeconds < maxWaitTime) {
      try {
        final result = await _callRpc('eth_getTransactionReceipt', [transactionHash]);
        if (result != null && result is Map) {
          // 转换区块号为整数
          final blockNumberHex = result['blockNumber'] as String?;
          if (blockNumberHex != null) {
            final blockNumber = int.parse(blockNumberHex.substring(2), radix: 16);
            return {
              'blockNumber': blockNumber,
              'transactionHash': transactionHash,
              'status': result['status'],
            };
          }
          return result as Map<String, dynamic>;
        }
      } catch (e) {
        // 交易可能还在pending，继续等待
      }
      
      // 等待1秒后重试
      await Future.delayed(const Duration(seconds: 1));
    }

    throw TimeoutException(
      'Transaction confirmation timeout after $maxWaitTime seconds',
      const Duration(seconds: 60),
    );
  }

  /// 获取交易信息
  Future<Map<String, dynamic>?> getTransaction(String transactionHash) async {
    if (!_initialized) await initialize();
    try {
      final result = await _callRpc('eth_getTransactionByHash', [transactionHash]);
      return result as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// 验证地址格式
  static bool isValidAddress(String address) {
    if (!address.startsWith('0x') || address.length != 42) {
      return false;
    }
    try {
      // 验证是否为有效的十六进制
      int.parse(address.substring(2), radix: 16);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 从私钥获取地址（简化版本）
  /// 注意：这是一个简化实现，实际应该使用椭圆曲线加密
  /// 对于Ganache测试环境，可以使用Ganache提供的账户
  static String getAddressFromPrivateKey(String privateKey) {
    try {
      // 简化实现：使用私钥的哈希生成地址
      // 实际应用中应该使用椭圆曲线加密
      // 这里仅用于测试，建议使用Ganache提供的账户
      if (privateKey.length != 64) {
        throw Exception('Private key must be 64 hexadecimal characters');
      }
      
      // 验证私钥格式
      int.parse(privateKey, radix: 16);
      
      // 注意：这是一个占位实现
      // 实际应该使用eth_privateKeyToAddress或类似方法
      // 对于测试，建议直接从Ganache获取账户地址
      throw Exception(
        'Please use an account address from Ganache. '
        'For testing, copy the address directly from Ganache interface.'
      );
    } catch (e) {
      if (e.toString().contains('Please use')) {
        rethrow;
      }
      throw Exception('Invalid private key: $e');
    }
  }

  /// 清理资源
  void dispose() {
    _initialized = false;
  }
}

/// 超时异常
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;

  TimeoutException(this.message, this.timeout);

  @override
  String toString() => message;
}
