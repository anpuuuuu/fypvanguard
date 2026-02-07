// lib/payment/services/wallet_service.dart
// Wallet service for managing blockchain accounts

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../services/blockchain_service.dart';

/// Wallet service for managing blockchain accounts (format, validate, balance).
/// Recipient address for payment is set in blockchain_payment_page.dart (kRecipientAddress) for easy presentation.
class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  /// Default management wallet address (recipient) when Firestore is not set.
  /// Using account at index 2 from Ganache as management wallet.
  static const String _defaultManagementWalletAddress = '0x86eC428176911F985A2200915cddADFe84471ccd';

  /// Override from Firestore settings/blockchain.managementWalletAddress (for cross-PC: same chain = same recipient).
  static String? _managementWalletAddressOverride;
  static bool _settingsLoaded = false;

  /// Load blockchain settings from Firestore (rpcUrl is loaded in BlockchainService).
  /// Call this so that when testing from another PC, the same recipient address is used on the shared Ganache.
  static Future<void> initialize() async {
    if (_settingsLoaded) return;
    _settingsLoaded = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('blockchain')
          .get();
      final data = doc.data();
      final addr = data?['managementWalletAddress'] as String?;
      if (addr != null && addr.trim().isNotEmpty && BlockchainService.isValidAddress(addr.trim())) {
        _managementWalletAddressOverride = addr.trim();
      }
    } catch (_) {
      // No document or no network: keep using default
    }
  }

  /// Management wallet address (recipient for payments). From Firestore if set, else default.
  /// For cross-PC testing: set in Firestore so all devices use the same recipient on the same Ganache.
  static String get managementWalletAddress =>
      _managementWalletAddressOverride ?? _defaultManagementWalletAddress;

  /// Generate a new random Ethereum address and private key
  /// Note: This is for testing purposes only. In production, use proper key generation libraries
  Future<Map<String, String>> generateNewAccount() async {
    // Generate random private key (64 hex characters)
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final privateKeyHex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    
    // For simplicity, we'll use a deterministic address generation
    // In production, use proper Ethereum address derivation from private key
    final hash = sha256.convert(utf8.encode(privateKeyHex));
    final addressBytes = hash.bytes.take(20).toList();
    final address = '0x${addressBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    return {
      'address': address,
      'privateKey': privateKeyHex,
    };
  }

  /// Get account balance from blockchain
  Future<String> getAccountBalance(String address) async {
    try {
      final blockchainService = BlockchainService();
      await blockchainService.initialize();
      final balance = await blockchainService.getBalance(address);
      return '$balance ETH';
    } catch (e) {
      return 'Error loading balance';
    }
  }

  /// Validate if an address is valid
  static bool isValidAddress(String address) {
    return BlockchainService.isValidAddress(address);
  }

  /// Validate if a private key is valid
  static bool isValidPrivateKey(String privateKey) {
    var cleaned = privateKey.trim().toLowerCase();
    if (cleaned.startsWith('0x')) {
      cleaned = cleaned.substring(2);
    }
    cleaned = cleaned.replaceAll(' ', '');
    
    if (cleaned.length != 64) return false;
    
    try {
      BigInt.parse(cleaned, radix: 16);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Format private key (remove 0x prefix and spaces)
  static String formatPrivateKey(String privateKey) {
    var cleaned = privateKey.trim().toLowerCase();
    if (cleaned.startsWith('0x')) {
      cleaned = cleaned.substring(2);
    }
    return cleaned.replaceAll(' ', '');
  }

  /// Format address (ensure lowercase, with 0x prefix)
  static String formatAddress(String address) {
    var cleaned = address.trim().toLowerCase();
    if (!cleaned.startsWith('0x')) {
      cleaned = '0x$cleaned';
    }
    return cleaned;
  }
}
