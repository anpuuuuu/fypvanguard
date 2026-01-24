// lib/payment/services/wallet_service.dart
// Wallet service for managing blockchain accounts

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../services/blockchain_service.dart';

/// Pre-configured Ganache accounts from the screenshot
/// These are test accounts with 100 ETH each
class PreconfiguredAccount {
  final String address;
  final String privateKey;
  final int index;
  final String balance;

  PreconfiguredAccount({
    required this.address,
    required this.privateKey,
    required this.index,
    required this.balance,
  });
}

/// Wallet service for managing blockchain accounts
class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  /// Pre-configured accounts from Ganache (from screenshot)
  /// These are test accounts that can be used directly
  /// Updated to match the actual Ganache accounts shown in the screenshot
  static final List<PreconfiguredAccount> preconfiguredAccounts = [
    PreconfiguredAccount(
      address: '0xCF09Ee496E515d685efE356ED1C39097feA26CD4',
      privateKey: '', // User needs to get this from Ganache (click key icon)
      index: 0,
      balance: '100.00 ETH',
    ),
    PreconfiguredAccount(
      address: '0xc69C6bd2bD8CD133DFa0bF492c9261C83BDF852a',
      privateKey: '', // User needs to get this from Ganache (click key icon)
      index: 1,
      balance: '100.00 ETH',
    ),
    PreconfiguredAccount(
      address: '0x86eC428176911F985A2200915cddADFe84471ccd',
      privateKey: '', // User needs to get this from Ganache (click key icon)
      index: 2,
      balance: '100.00 ETH',
    ),
    PreconfiguredAccount(
      address: '0x26E23EfA19E8996E5Eefd85022deD5e2FC9FFd9E',
      privateKey: '', // User needs to get this from Ganache (click key icon)
      index: 3,
      balance: '100.00 ETH',
    ),
    PreconfiguredAccount(
      address: '0x9a8C9F1B5ef76aFa1f4b74820ba101B46f09A450',
      privateKey: '', // User needs to get this from Ganache (click key icon)
      index: 4,
      balance: '100.00 ETH',
    ),
    PreconfiguredAccount(
      address: '0xFcE4e96Bd962e5ba4c53bDf5094748dEA009fa0B',
      privateKey: '', // User needs to get this from Ganache (click key icon)
      index: 5,
      balance: '100.00 ETH',
    ),
    PreconfiguredAccount(
      address: '0x8017b486E73bc85E1E90aE224215b0354647fe5D',
      privateKey: '', // User needs to get this from Ganache (click key icon)
      index: 6,
      balance: '100.00 ETH',
    ),
  ];

  /// Management wallet address (recipient address for payments)
  /// Using account at index 2 from Ganache as management wallet
  static const String managementWalletAddress = '0x86eC428176911F985A2200915cddADFe84471ccd';

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
