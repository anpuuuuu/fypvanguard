// lib/payment/ui/blockchain_payment_page.dart
// Blockchain payment – manual address + private key only. Recipient address is set in code for easy presentation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../controllers/payment_controller.dart';
import '../services/wallet_service.dart';
import '../services/blockchain_service.dart';

// ========== RECIPIENT ADDRESS (payment goes here) ==========
// • This PC: set to any Ganache account on this machine (e.g. Account 2). Run Ganache here; balance will deduct on this PC.
// • Another PC: before presenting, change this to one of THAT PC's Ganache accounts (copy from Ganache ACCOUNTS tab).
//   Run Ganache on that PC and run the app there — the app connects to local Ganache, so balance deduction works on that PC.
const String kRecipientAddress = '0x86eC428176911F985A2200915cddADFe84471ccd';

class BlockchainPaymentPage extends StatefulWidget {
  final double amount;
  final FeeType feeType;
  final String? feeTypeKey;
  final String feeTypeName;
  final String description;

  const BlockchainPaymentPage({
    Key? key,
    required this.amount,
    required this.feeType,
    this.feeTypeKey,
    required this.feeTypeName,
    required this.description,
  }) : super(key: key);

  @override
  State<BlockchainPaymentPage> createState() => _BlockchainPaymentPageState();
}

class _BlockchainPaymentPageState extends State<BlockchainPaymentPage> {
  final PaymentController _controller = PaymentController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fromAddressController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  bool _isProcessing = false;

  static const double _rmToEthRate = 0.0000846;
  double get _ethAmount => widget.amount * _rmToEthRate;

  @override
  void initState() {
    super.initState();
    _controller.initialize();
  }

  @override
  void dispose() {
    _fromAddressController.dispose();
    _privateKeyController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final fromAddress = WalletService.formatAddress(_fromAddressController.text);
    final privateKey = WalletService.formatPrivateKey(_privateKeyController.text);

    setState(() => _isProcessing = true);

    try {
      final blockchainService = BlockchainService();
      await blockchainService.initialize();
      final isConnected = await blockchainService.testConnection();
      if (!isConnected) {
        throw Exception(
          'Cannot connect to Ganache at ${BlockchainService.rpcUrl}. '
          'Ensure Ganache is running with RPC Server: HTTP://0.0.0.0:7545'
        );
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Confirm Payment', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('RM ${widget.amount.toStringAsFixed(2)} → ${_ethAmount.toStringAsFixed(6)} ETH', style: GoogleFonts.montserrat()),
              const SizedBox(height: 8),
              Text('To: ${kRecipientAddress.substring(0, 10)}...${kRecipientAddress.substring(kRecipientAddress.length - 8)}', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.montserrat())),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
              child: Text('Confirm', style: GoogleFonts.montserrat(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) {
        setState(() => _isProcessing = false);
        return;
      }

      final transaction = await _controller.processBlockchainPayment(
        amount: widget.amount,
        ethAmount: _ethAmount,
        feeType: widget.feeType,
        feeTypeKey: widget.feeTypeKey,
        fromAddress: fromAddress,
        privateKey: privateKey,
        toAddress: kRecipientAddress,
        description: widget.description,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment successful! Transaction ID: ${transaction.id}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('sender account not recognized') || msg.contains('account not recognized')) {
        _showError(
          'Sender account not recognized. Use an account that appears in your Ganache window on this PC: '
          'copy the address and private key by clicking the key icon next to that account. '
          'The address must be exactly one of the accounts listed in Ganache (same network as the app).'
        );
      } else {
        _showError('Payment failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Blockchain Payment', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: Colors.black87)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConnectionCard(),
              const SizedBox(height: 16),
              _buildSummaryCard(),
              const SizedBox(height: 20),
              Text('Payer (from Ganache)', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Use address and private key from this PC’s Ganache (click key icon to copy).', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fromAddressController,
                decoration: InputDecoration(
                  labelText: 'Sender address',
                  hintText: '0x... (42 characters)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.account_balance_wallet),
                ),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-Fx]'))],
                onChanged: (value) {
                  final cleaned = value.trim().toLowerCase().replaceAll(' ', '');
                  if (cleaned != value) {
                    _fromAddressController.value = TextEditingValue(text: cleaned, selection: TextSelection.collapsed(offset: cleaned.length));
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter sender address';
                  final cleaned = value.trim().toLowerCase().replaceAll(' ', '');
                  if (!cleaned.startsWith('0x')) return 'Address must start with 0x';
                  if (cleaned.length != 42) return 'Address must be 42 characters (0x + 40 hex)';
                  if (!WalletService.isValidAddress(cleaned)) return 'Invalid address format';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _privateKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Private key',
                  hintText: '64 hex characters',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.vpn_key),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter private key';
                  if (!WalletService.isValidPrivateKey(value)) return 'Private key must be 64 hexadecimal characters';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildRecipientCard(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : Text('Confirm Payment  RM ${widget.amount.toStringAsFixed(2)} (${_ethAmount.toStringAsFixed(6)} ETH)', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    final rpcUrl = BlockchainService.rpcUrl;
    return Card(
      elevation: 1,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text('Ganache', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900)),
              ],
            ),
            const SizedBox(height: 6),
            Text(rpcUrl, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.feeTypeName, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Amount', style: GoogleFonts.montserrat(color: Colors.grey)),
                Text('RM ${widget.amount.toStringAsFixed(2)}  →  ${_ethAmount.toStringAsFixed(6)} ETH', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: Colors.red.shade700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientCard() {
    return Card(
      elevation: 1,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.arrow_forward, color: Colors.green.shade700, size: 18),
                const SizedBox(width: 6),
                Text('Payment to (recipient)', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade900)),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              kRecipientAddress,
              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.green.shade900),
            ),
          ],
        ),
      ),
    );
  }
}
