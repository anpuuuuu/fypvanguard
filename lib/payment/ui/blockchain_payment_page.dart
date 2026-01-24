// lib/payment/ui/blockchain_payment_page.dart
// Simplified blockchain payment page with account selection

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../controllers/payment_controller.dart';
import '../services/wallet_service.dart';
import '../services/blockchain_service.dart';

class BlockchainPaymentPage extends StatefulWidget {
  final double amount;
  final FeeType feeType;
  final String description;

  const BlockchainPaymentPage({
    Key? key,
    required this.amount,
    required this.feeType,
    required this.description,
  }) : super(key: key);

  @override
  State<BlockchainPaymentPage> createState() => _BlockchainPaymentPageState();
}

class _BlockchainPaymentPageState extends State<BlockchainPaymentPage> {
  final PaymentController _controller = PaymentController();
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;
  bool _showAdvancedOptions = false;

  // Account selection
  PreconfiguredAccount? _selectedAccount;
  Map<String, String>? _generatedAccount;
  bool _useGeneratedAccount = false;

  // Manual input (advanced)
  final TextEditingController _fromAddressController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  bool _useManualInput = false;
  
  // Private key input for preconfigured accounts
  final TextEditingController _preconfiguredPrivateKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.initialize();
  }

  @override
  void dispose() {
    _fromAddressController.dispose();
    _privateKeyController.dispose();
    _preconfiguredPrivateKeyController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generateNewAccount() async {
    setState(() => _isProcessing = true);
    try {
      final account = await WalletService().generateNewAccount();
      setState(() {
        _generatedAccount = account;
        _useGeneratedAccount = true;
        _selectedAccount = null;
        _useManualInput = false;
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New account generated! Please save your private key.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processPayment() async {
    String? fromAddress;
    String? privateKey;

    if (_useManualInput) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
      fromAddress = WalletService.formatAddress(_fromAddressController.text);
      privateKey = WalletService.formatPrivateKey(_privateKeyController.text);
    } else if (_useGeneratedAccount && _generatedAccount != null) {
      fromAddress = WalletService.formatAddress(_generatedAccount!['address']!);
      privateKey = WalletService.formatPrivateKey(_generatedAccount!['privateKey']!);
    } else if (_selectedAccount != null) {
      fromAddress = WalletService.formatAddress(_selectedAccount!.address);
      // Get private key from input field if preconfigured account doesn't have it
      if (_selectedAccount!.privateKey.isEmpty) {
        final inputKey = _preconfiguredPrivateKeyController.text.trim();
        if (inputKey.isEmpty) {
          _showError('Please enter the private key for this account (get it from Ganache)');
          return;
        }
        if (!WalletService.isValidPrivateKey(inputKey)) {
          _showError('Invalid private key format (must be 64 hexadecimal characters)');
          return;
        }
        privateKey = WalletService.formatPrivateKey(inputKey);
      } else {
        privateKey = WalletService.formatPrivateKey(_selectedAccount!.privateKey);
      }
    } else {
      _showError('Please select an account or generate a new account');
      return;
    }

    if (fromAddress == null || privateKey == null) {
      _showError('Account information is incomplete');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Test connection to Ganache first
      final blockchainService = BlockchainService();
      await blockchainService.initialize();
      final isConnected = await blockchainService.testConnection();
      
      if (!isConnected) {
        final rpcUrl = BlockchainService.rpcUrl;
        throw Exception(
          'Cannot connect to Ganache at $rpcUrl\n\n'
          'Please ensure:\n'
          '1. Ganache is running\n'
          '2. RPC Server is set to HTTP://0.0.0.0:7545 in Ganache\n'
          '3. For Android Emulator: The app uses http://10.0.2.2:7545\n'
          '4. For physical device: Update RPC URL in blockchain_service.dart\n'
          '5. Check if firewall is blocking port 7545\n\n'
          'Current RPC URL: $rpcUrl'
        );
      }
      
      final transaction = await _controller.processBlockchainPayment(
        amount: widget.amount,
        feeType: widget.feeType,
        fromAddress: fromAddress,
        privateKey: privateKey,
        toAddress: WalletService.managementWalletAddress,
        description: widget.description,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful! Transaction ID: ${transaction.id}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorWithRetry('Payment failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showErrorWithRetry(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _processPayment(),
          ),
        ),
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
        title: Text(
          'Blockchain Payment',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection info card
            _buildConnectionInfoCard(),

            const SizedBox(height: 16),

            // Payment summary
            _buildSummaryCard(),

            const SizedBox(height: 24),

            // Account selection section
            Text(
              'Select Payment Account',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            // Pre-configured accounts
            _buildPreconfiguredAccountsSection(),

            // Private key input for preconfigured account
            if (_selectedAccount != null && 
                !_useGeneratedAccount && 
                !_useManualInput &&
                _selectedAccount!.privateKey.isEmpty) ...[
              const SizedBox(height: 16),
              _buildPreconfiguredPrivateKeyInput(),
            ],

            const SizedBox(height: 16),

            // Generate new account button
            _buildGenerateAccountButton(),

            const SizedBox(height: 16),

            // Advanced options toggle
            _buildAdvancedOptionsToggle(),

            // Manual input form (advanced)
            if (_showAdvancedOptions && _useManualInput)
              _buildManualInputForm(),

            const SizedBox(height: 24),

            // Payment button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isProcessing || 
                    (!_useManualInput && !_useGeneratedAccount && _selectedAccount == null))
                    ? null
                    : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Confirm Payment RM ${widget.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionInfoCard() {
    final rpcUrl = BlockchainService.rpcUrl;
    return Card(
      elevation: 1,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Ganache Connection',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'RPC URL: $rpcUrl',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ensure Ganache is running with RPC Server: HTTP://0.0.0.0:7545',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                color: Colors.blue.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Summary',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fee Type',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  _getFeeTypeName(widget.feeType),
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amount',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'RM ${widget.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreconfiguredAccountsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pre-configured Accounts (Ganache Test Accounts)',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...WalletService.preconfiguredAccounts.map((account) {
              final isSelected = _selectedAccount?.index == account.index && 
                  !_useGeneratedAccount && !_useManualInput;
              return _buildAccountCard(
                account: account,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedAccount = account;
                    _useGeneratedAccount = false;
                    _useManualInput = false;
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard({
    required PreconfiguredAccount account,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final needsPrivateKey = account.privateKey.isEmpty;
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.orange.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.orange : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: isSelected,
                    onChanged: (_) => onTap(),
                    activeColor: Colors.orange,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account ${account.index + 1}',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${account.address.substring(0, 10)}...${account.address.substring(account.address.length - 8)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          account.balance,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (needsPrivateKey && isSelected) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please enter the private key for this account below (get it from Ganache)',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateAccountButton() {
    if (_useGeneratedAccount && _generatedAccount != null) {
      return Card(
        elevation: 2,
        color: Colors.green.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.green.shade300, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'New Account Generated',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Address: ${_generatedAccount!['address']}',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please save your private key! New accounts need funds imported from Ganache to be usable.',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isProcessing ? null : _generateNewAccount,
        icon: const Icon(Icons.add_circle_outline),
        label: Text(
          'Generate New Account',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: Colors.orange.shade700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedOptionsToggle() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _showAdvancedOptions = !_showAdvancedOptions;
            if (!_showAdvancedOptions) {
              _useManualInput = false;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Advanced Options (Manual Address and Private Key Input)',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                _showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualInputForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _useManualInput,
                    onChanged: (value) {
                      setState(() {
                        _useManualInput = value ?? false;
                        if (!_useManualInput) {
                          _selectedAccount = null;
                          _useGeneratedAccount = false;
                        }
                      });
                    },
                    activeColor: Colors.orange,
                  ),
                  Expanded(
                    child: Text(
                      'Use manually entered address and private key',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (_useManualInput) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fromAddressController,
                  decoration: InputDecoration(
                    labelText: 'Sender Address',
                    hintText: '0x...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter sender address';
                    }
                    if (!WalletService.isValidAddress(value)) {
                      return 'Invalid Ethereum address format';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _privateKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Private Key',
                    hintText: '64 hexadecimal characters',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.vpn_key),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter private key';
                    }
                    if (!WalletService.isValidPrivateKey(value)) {
                      return 'Invalid private key format (must be 64 hexadecimal characters)';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreconfiguredPrivateKeyInput() {
    return Card(
      elevation: 2,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Enter Private Key',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Account ${_selectedAccount!.index + 1} requires a private key to make payments.',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.orange.shade900,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _preconfiguredPrivateKeyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Private Key (Get from Ganache)',
                hintText: 'Click the key icon in Ganache to copy the private key',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.vpn_key),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter private key';
                }
                if (!WalletService.isValidPrivateKey(value)) {
                  return 'Invalid private key format (must be 64 hexadecimal characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'In Ganache, click the key icon (🔑) next to the account to copy the private key',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFeeTypeName(FeeType feeType) {
    switch (feeType) {
      case FeeType.managementFee:
        return 'Management Fee';
      case FeeType.maintenanceFee:
        return 'Maintenance Fee';
      case FeeType.lateFee:
        return 'Late Fee';
      case FeeType.other:
        return 'Other Fee';
    }
  }
}
