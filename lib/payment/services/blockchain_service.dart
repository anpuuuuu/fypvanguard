// lib/payment/services/blockchain_service.dart
// Blockchain payment service - Using Ganache test network
// Uses HTTP to directly call RPC, does not depend on web3dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Blockchain payment service
/// Connects to Ganache test network for Ethereum transactions
class BlockchainService {
  // Ganache configuration (from screenshot)
  // Note: RPC URL depends on where the app is running:
  // - Android Emulator: use 'http://10.0.2.2:7545' (10.0.2.2 is special IP for host machine)
  // - iOS Simulator: use 'http://localhost:7545' or 'http://127.0.0.1:7545'
  // - Physical Device: use your computer's IP address, e.g., 'http://192.168.1.100:7545'
  // - Web: use 'http://localhost:7545' (if Ganache allows CORS)
  static String get rpcUrl {
    if (kIsWeb) {
      // For web, use localhost
      return 'http://localhost:7545';
    } else if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost
      return 'http://10.0.2.2:7545';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost
      return 'http://localhost:7545';
    } else {
      // Default fallback
      return 'http://localhost:7545';
    }
  }
  
  static const int chainId = 5777; // Network ID
  static const String networkName = 'Ganache Local';
  
  bool _initialized = false;

  /// Initialize service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Call RPC method
  Future<dynamic> _callRpc(String method, List<dynamic> params) async {
    try {
      // Debug: Print the RPC URL being used
      final currentRpcUrl = rpcUrl;
      print('🔗 Connecting to Ganache at: $currentRpcUrl');
      
      final uri = Uri.parse(currentRpcUrl);
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': method,
          'params': params,
          'id': 1,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout. Please check if Ganache is running on $rpcUrl');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('error')) {
          final error = data['error'];
          throw Exception('RPC Error: ${error['message'] ?? error}');
        }
        return data['result'];
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception(
        'Cannot connect to Ganache at $rpcUrl.\n'
        'Please ensure:\n'
        '1. Ganache is running\n'
        '2. RPC Server is set to HTTP://0.0.0.0:7545 in Ganache\n'
        '3. For Android Emulator, use http://10.0.2.2:7545\n'
        '4. For physical device, use your computer\'s IP address\n'
        'Error: ${e.message}'
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Connection failed to Ganache at $rpcUrl.\n'
        'Please check if Ganache is running and accessible.\n'
        'Error: ${e.message}'
      );
    } catch (e) {
      if (e.toString().contains('timeout') || e.toString().contains('Connection')) {
        throw Exception(
          'Cannot connect to Ganache at $rpcUrl.\n'
          'Please ensure Ganache is running and the RPC server is accessible.\n'
          'Error: $e'
        );
      }
      throw Exception('RPC call failed: $e');
    }
  }
  
  /// Test connection to Ganache
  Future<bool> testConnection() async {
    try {
      await _callRpc('eth_blockNumber', []);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get account balance (ETH)
  Future<String> getBalance(String address) async {
    if (!_initialized) await initialize();
    final result = await _callRpc('eth_getBalance', [address, 'latest']);
    final balanceHex = result as String;
    // Convert to ETH (from Wei)
    final balanceWei = BigInt.parse(balanceHex.substring(2), radix: 16);
    final balanceEth = balanceWei / BigInt.from(1e18.toInt());
    return balanceEth.toString();
  }

  /// Get current Gas price
  Future<String> getGasPrice() async {
    if (!_initialized) await initialize();
    final result = await _callRpc('eth_gasPrice', []);
    return result as String;
  }

  /// Get transaction count (nonce)
  Future<int> getTransactionCount(String address) async {
    if (!_initialized) await initialize();
    final result = await _callRpc('eth_getTransactionCount', [address, 'latest']);
    final countHex = result as String;
    return int.parse(countHex.substring(2), radix: 16);
  }

  /// Send ETH transaction
  /// [fromAddress] - Sender address (from Ganache)
  /// [privateKey] - Sender private key (hexadecimal string, without 0x prefix)
  /// [toAddress] - Recipient address
  /// [amount] - Amount (ETH)
  /// [gasLimit] - Gas limit (optional, default 21000)
  /// 
  /// Returns transaction hash
  Future<String> sendTransaction({
    required String fromAddress,
    required String privateKey,
    required String toAddress,
    required double amount,
    int? gasLimit,
  }) async {
    if (!_initialized) await initialize();

    try {
      // Validate sender address
      if (!isValidAddress(fromAddress)) {
        throw Exception('Invalid sender address');
      }
      
      // Validate recipient address
      if (!isValidAddress(toAddress)) {
        throw Exception('Invalid recipient address');
      }
      
      // Convert amount to Wei (hexadecimal)
      final amountWei = BigInt.from((amount * 1e18).toInt());
      final amountHex = '0x${amountWei.toRadixString(16)}';

      // Get Gas price
      final gasPriceHex = await getGasPrice();
      
      // Get nonce
      final nonce = await getTransactionCount(fromAddress);
      final nonceHex = '0x${nonce.toRadixString(16)}';

      // Build transaction object
      // Note: Ganache allows direct transaction sending, accounts are automatically unlocked
      final transaction = {
        'from': fromAddress,
        'to': toAddress,
        'value': amountHex,
        'gas': '0x${(gasLimit ?? 21000).toRadixString(16)}',
        'gasPrice': gasPriceHex,
        'nonce': nonceHex,
      };

      // Ganache supports direct transaction sending (accounts auto-unlocked)
      // In production environment, should use eth_signTransaction + eth_sendRawTransaction
      final result = await _callRpc('eth_sendTransaction', [transaction]);
      
      return result as String;
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }

  /// Wait for transaction confirmation
  /// [transactionHash] - Transaction hash
  /// [maxWaitTime] - Maximum wait time (seconds), default 60 seconds
  /// 
  /// Returns transaction receipt, including block number and other information
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
          // Convert block number to integer
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
        // Transaction may still be pending, continue waiting
      }
      
      // Wait 1 second before retry
      await Future.delayed(const Duration(seconds: 1));
    }

    throw TimeoutException(
      'Transaction confirmation timeout after $maxWaitTime seconds',
      const Duration(seconds: 60),
    );
  }

  /// Get transaction information
  Future<Map<String, dynamic>?> getTransaction(String transactionHash) async {
    if (!_initialized) await initialize();
    try {
      final result = await _callRpc('eth_getTransactionByHash', [transactionHash]);
      return result as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Validate address format
  static bool isValidAddress(String address) {
    if (address.isEmpty) return false;
    
    // Remove whitespace and convert to lowercase
    final cleaned = address.trim().toLowerCase();
    
    // Must start with 0x
    if (!cleaned.startsWith('0x')) {
      return false;
    }
    
    // Must be exactly 42 characters (0x + 40 hex chars)
    if (cleaned.length != 42) {
      return false;
    }
    
    try {
      // Validate if it's valid hexadecimal
      // Check each character after 0x is a valid hex digit
      final hexPart = cleaned.substring(2);
      if (hexPart.length != 40) return false;
      
      // Validate all characters are hex digits
      for (int i = 0; i < hexPart.length; i++) {
        final char = hexPart[i];
        if (!((char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) || // 0-9
              (char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 102))) { // a-f
          return false;
        }
      }
      
      // Try to parse as BigInt to ensure it's valid
      BigInt.parse(hexPart, radix: 16);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _initialized = false;
  }
}

/// Timeout exception
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;

  TimeoutException(this.message, this.timeout);

  @override
  String toString() => message;
}
