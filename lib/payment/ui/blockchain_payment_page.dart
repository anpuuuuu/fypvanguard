// lib/payment/ui/blockchain_payment_page.dart
// Simplified blockchain payment page with account selection

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../controllers/payment_controller.dart';
import '../services/wallet_service.dart';
import '../services/blockchain_service.dart';

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
  bool _isProcessing = false;

  // Account selection
  PreconfiguredAccount? _selectedAccount;

  // Manual input (advanced)
  final TextEditingController _fromAddressController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  bool _useManualInput = false;
  
  // Private key input for preconfigured accounts
  final TextEditingController _preconfiguredPrivateKeyController = TextEditingController();

  // RM to ETH conversion rate
  // Based on approximate rate: 1 RM ≈ 0.0000846 ETH (or 1 ETH ≈ 11,820 RM)
  // This is a fixed rate for testing. In production, you should fetch real-time rates from an API
  static const double _rmToEthRate = 0.0000846; // 1 RM = 0.0000846 ETH

  /// Convert RM amount to ETH
  double _convertRmToEth(double rmAmount) {
    return rmAmount * _rmToEthRate;
  }

  /// Get ETH amount for display
  double get _ethAmount => _convertRmToEth(widget.amount);

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

  Future<void> _processPayment() async {
    String? fromAddress;
    String? privateKey;

    if (_useManualInput) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
      fromAddress = WalletService.formatAddress(_fromAddressController.text);
      privateKey = WalletService.formatPrivateKey(_privateKeyController.text);
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
      
      // Convert RM amount to ETH before sending
      final ethAmount = _convertRmToEth(widget.amount);
      
      // Show confirmation dialog with conversion
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Confirm Payment', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment Amount:', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('RM ${widget.amount.toStringAsFixed(2)}', style: GoogleFonts.montserrat(fontSize: 18)),
              const SizedBox(height: 12),
              Text('ETH Amount:', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('${ethAmount.toStringAsFixed(6)} ETH', 
                style: GoogleFonts.montserrat(fontSize: 18, color: Colors.blue.shade700)),
              const SizedBox(height: 12),
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
                        'Rate: 1 RM = ${_rmToEthRate.toStringAsFixed(6)} ETH',
                        style: GoogleFonts.montserrat(fontSize: 11, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.montserrat()),
            ),
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
        amount: widget.amount, // Original RM amount
        ethAmount: ethAmount, // Converted ETH amount
        feeType: widget.feeType,
        feeTypeKey: widget.feeTypeKey,
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

  void _showAccountSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Select Account',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: WalletService.preconfiguredAccounts.length,
            itemBuilder: (context, index) {
              final account = WalletService.preconfiguredAccounts[index];
              return ListTile(
                title: Text(
                  'Account ${account.index + 1}',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${account.address.substring(0, 10)}...${account.address.substring(account.address.length - 8)}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.content_copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: account.address));
                    Navigator.pop(context);
                    _fromAddressController.text = account.address;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Address copied to input field'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Copy address',
                ),
                onTap: () {
                  _fromAddressController.text = account.address;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Address filled from Account ${account.index + 1}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );
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
                !_useManualInput &&
                _selectedAccount!.privateKey.isEmpty) ...[
              const SizedBox(height: 16),
              _buildPreconfiguredPrivateKeyInput(),
            ],

            const SizedBox(height: 16),

            // Advanced options (Manual Address and Private Key Input)
            _buildManualInputForm(),

            const SizedBox(height: 24),

            // Payment button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isProcessing || 
                    (!_useManualInput && _selectedAccount == null))
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
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Confirm Payment',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'RM ${widget.amount.toStringAsFixed(2)} (${_ethAmount.toStringAsFixed(6)} ETH)',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
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
                  widget.feeTypeName,
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
                  'Amount (RM)',
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'ETH Amount',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_ethAmount.toStringAsFixed(6)} ETH',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Rate: 1 RM ≈ ${_rmToEthRate.toStringAsFixed(6)} ETH',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
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
                  !_useManualInput;
              return _buildAccountCard(
                account: account,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedAccount = account;
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
    return FutureBuilder<String>(
      future: WalletService().getAccountBalance(account.address),
      builder: (context, snapshot) {
        final balance = snapshot.hasData && !snapshot.hasError
            ? snapshot.data!
            : account.balance;
        final isLoadingBalance = snapshot.connectionState == ConnectionState.waiting;
        
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
                            if (isLoadingBalance)
                              Row(
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Loading balance...',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'Balance: $balance ETH',
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
      },
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
              Text(
                'Advanced Options (Manual Address and Private Key Input)',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _useManualInput,
                    onChanged: (value) {
                      setState(() {
                        _useManualInput = value ?? false;
                        if (!_useManualInput) {
                          _selectedAccount = null;
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fromAddressController,
                        decoration: InputDecoration(
                          labelText: 'Sender Address',
                          hintText: '0x... (42 characters)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.account_balance_wallet),
                          helperText: 'Ethereum address must be 42 characters (0x + 40 hex)',
                        ),
                        inputFormatters: [
                          // Remove spaces and convert to lowercase
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-Fx]')),
                        ],
                        onChanged: (value) {
                          // Auto-format: remove spaces and ensure lowercase
                          final cleaned = value.trim().toLowerCase().replaceAll(' ', '');
                          if (cleaned != value && _fromAddressController.text != cleaned) {
                            final selection = _fromAddressController.selection;
                            _fromAddressController.value = TextEditingValue(
                              text: cleaned,
                              selection: TextSelection.collapsed(offset: cleaned.length),
                            );
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter sender address';
                          }
                          // Clean the address before validation
                          final cleaned = value.trim().toLowerCase().replaceAll(' ', '');
                          if (!cleaned.startsWith('0x')) {
                            return 'Address must start with 0x';
                          }
                          if (cleaned.length != 42) {
                            return 'Address must be 42 characters (currently ${cleaned.length}). Expected: 0x + 40 hex characters';
                          }
                          if (!WalletService.isValidAddress(cleaned)) {
                            return 'Invalid Ethereum address format. Must be 42 characters: 0x followed by 40 hexadecimal characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_drop_down),
                      tooltip: 'Select from preconfigured accounts',
                      onPressed: () => _showAccountSelector(),
                    ),
                  ],
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
}
