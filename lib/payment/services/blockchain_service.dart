// lib/payment/services/blockchain_service.dart
// Blockchain payment service - Using Ganache test network.
// Signs transactions locally with web3dart so any address+privateKey works (no "sender account not recognized").

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart' as web3;

/// Blockchain payment service
/// Connects to Ganache test network for Ethereum transactions.
/// RPC selection: tries LOCAL Ganache first (localhost / 10.0.2.2); if that fails, uses
/// Firestore settings/blockchain.rpcUrl so you can use one chain from multiple devices OR
/// run app + Ganache on the same PC (e.g. presentation) and have balance deduct locally.
class BlockchainService {
  /// From Firestore settings/blockchain.rpcUrl (fallback when local Ganache is not reachable).
  static String? _rpcUrlOverride;

  /// Resolved URL: local if reachable, else Firestore override. Set in initialize().
  static String? _effectiveRpcUrl;

  /// Default RPC URL by platform (local Ganache on this device).
  static String get _defaultRpcUrl {
    if (kIsWeb) {
      return 'http://localhost:7545';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:7545';
    }
    if (Platform.isIOS) {
      return 'http://localhost:7545';
    }
    return 'http://localhost:7545';
  }

  /// Current RPC URL (local if available, else Firestore override, else default for error messages).
  static String get rpcUrl => _effectiveRpcUrl ?? _defaultRpcUrl;

  /// True when using Firestore remote RPC (not local Ganache).
  static bool get isUsingRemoteRpc =>
      _effectiveRpcUrl != null && _effectiveRpcUrl != _defaultRpcUrl;

  static const int chainId = 5777; // Network ID
  static const String networkName = 'Ganache Local';

  bool _initialized = false;

  /// Try a single RPC URL with a short timeout (for resolution only).
  static Future<bool> _tryConnect(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'eth_blockNumber',
          'params': [],
          'id': 1,
        }),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return !data.containsKey('error');
    } catch (_) {
      return false;
    }
  }

  /// Initialize service. Prefer local Ganache so that on presentation PC (app + Ganache on same machine) balance deducts locally; fallback to Firestore rpcUrl if local is not reachable.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('blockchain')
          .get();
      final data = doc.data();
      final url = data?['rpcUrl'] as String?;
      if (url != null && url.trim().isNotEmpty) {
        _rpcUrlOverride = url.trim();
      }
    } catch (_) {
      // No document or no network
    }

    // Prefer local Ganache: try default (this PC) first so presentation on same PC works and balance deducts there
    if (await _tryConnect(_defaultRpcUrl)) {
      _effectiveRpcUrl = _defaultRpcUrl;
      return;
    }
    if (_rpcUrlOverride != null && await _tryConnect(_rpcUrlOverride!)) {
      _effectiveRpcUrl = _rpcUrlOverride;
      return;
    }
    // Neither reachable; use default so error messages point to local and retry works when Ganache is started
    _effectiveRpcUrl = _defaultRpcUrl;
  }

  /// Call RPC method
  Future<dynamic> _callRpc(String method, List<dynamic> params) async {
    try {
      final uri = Uri.parse(rpcUrl);
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
    try {
      final result = await _callRpc('eth_getBalance', [address, 'latest']);
      final balanceHex = result as String;
      // Convert to ETH (from Wei)
      // 1 ETH = 10^18 Wei
      final balanceWei = BigInt.parse(balanceHex.substring(2), radix: 16);
      final weiPerEth = BigInt.from(1000000000000000000); // 10^18
      final ethWhole = balanceWei ~/ weiPerEth;
      final ethRemainder = balanceWei % weiPerEth;
      final ethDecimal = (ethRemainder.toDouble() / weiPerEth.toDouble());
      final totalEth = ethWhole.toDouble() + ethDecimal;
      
      // Format to 4 decimal places
      return totalEth.toStringAsFixed(4);
    } catch (e) {
      return 'Error';
    }
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

  /// Get chain ID from connected node (e.g. Ganache NETWORK ID). Returns null on failure.
  Future<int?> _getChainIdFromRpc() async {
    try {
      final result = await _callRpc('eth_chainId', []);
      if (result == null) return null;
      final hex = result.toString().trim();
      if (hex.isEmpty || !hex.startsWith('0x')) return null;
      return int.parse(hex.substring(2), radix: 16);
    } catch (_) {
      return null;
    }
  }

  /// Send ETH transaction (signed locally with private key so any Ganache account works).
  /// [fromAddress] - Sender address (must match the private key).
  /// [privateKey] - Sender private key (64 hex chars, with or without 0x).
  /// [toAddress] - Recipient address.
  /// [amount] - Amount (ETH).
  /// [gasLimit] - Gas limit (optional, default 21000).
  /// Returns transaction hash.
  Future<String> sendTransaction({
    required String fromAddress,
    required String privateKey,
    required String toAddress,
    required double amount,
    int? gasLimit,
  }) async {
    if (!_initialized) await initialize();

    try {
      if (!isValidAddress(fromAddress)) throw Exception('Invalid sender address');
      if (!isValidAddress(toAddress)) throw Exception('Invalid recipient address');

      final keyHex = privateKey.trim().toLowerCase().startsWith('0x')
          ? privateKey.trim().toLowerCase()
          : '0x${privateKey.trim().toLowerCase()}';
      final credentials = web3.EthPrivateKey.fromHex(keyHex);

      final amountWei = BigInt.from((amount * 1e18).toInt());
      final gasPriceHex = await getGasPrice();
      final gasPriceWei = BigInt.parse(gasPriceHex.startsWith('0x') ? gasPriceHex.substring(2) : gasPriceHex, radix: 16);

      final client = web3.Web3Client(rpcUrl, http.Client());
      try {
        final tx = web3.Transaction(
          to: web3.EthereumAddress.fromHex(toAddress),
          value: web3.EtherAmount.inWei(amountWei),
          maxGas: gasLimit ?? 21000,
          gasPrice: web3.EtherAmount.inWei(gasPriceWei),
        );
        // Use chain ID from Ganache so signature v matches (fixes "Invalid signature v value").
        final networkChainId = await _getChainIdFromRpc();
        final hash = await client.sendTransaction(
          credentials,
          tx,
          chainId: networkChainId ?? chainId,
          fetchChainIdFromNetworkId: networkChainId == null,
        );
        return hash;
      } finally {
        client.dispose();
      }
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
    
    // Remove all whitespace (including spaces in the middle) and convert to lowercase
    final cleaned = address.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    
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
