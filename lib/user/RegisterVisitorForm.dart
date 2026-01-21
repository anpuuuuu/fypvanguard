// lib/user/register_visitor_form.dart

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class RegisterVisitorForm extends StatefulWidget {
  final String entryType;
  const RegisterVisitorForm({Key? key, required this.entryType})
      : super(key: key);

  @override
  _RegisterVisitorFormState createState() => _RegisterVisitorFormState();
}

class _RegisterVisitorFormState extends State<RegisterVisitorForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  String? _parkingDuration;
  String? _residentId;
  bool _submitting = false;

  final _durationOptions = [
    {'label': '3 hours', 'value': '3h'},
    {'label': '5 hours', 'value': '5h'},
    {'label': '7 hours', 'value': '7h'},
    {'label': 'Overnight', 'value': 'overnight'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchResidentId();
  }

  Future<void> _fetchResidentId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final acct = await FirebaseFirestore.instance
        .collection('accounts')
        .doc(uid)
        .get();
    setState(() {
      _residentId = acct.data()?['residentId'] as String?;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _residentId == null) return;
    setState(() => _submitting = true);

    final data = {
      'visitorName': _nameCtrl.text.trim(),
      'phoneNumber': _phoneCtrl.text.trim(),
      'residentId': _residentId,
      'entryType': widget.entryType,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (widget.entryType == 'car') {
      data['vehiclePlate'] = _plateCtrl.text.trim();
      data['parkingDuration'] = _parkingDuration;
    }

    try {
      await FirebaseFirestore.instance.collection('visitors').add(data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visitor request submitted!')),
      );
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _plateCtrl.clear();
      setState(() => _parkingDuration = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCar = widget.entryType == 'car';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red.shade700,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Visitor Requests',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Register'),
              Tab(text: 'Recent'),
            ],
          ),
        ),
        body: _residentId == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            // ─── Register Tab ───────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildField(
                                  _nameCtrl, 'Visitor Name', Icons.person),
                              const SizedBox(height: 16),
// Phone Number
                              _buildField(
                                _phoneCtrl,
                                'Phone Number',
                                Icons.phone,
                                keyboard: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  if (!RegExp(r'^\d{7,15}$').hasMatch(v)) {
                                    return 'Enter 7–15 digits only';
                                  }
                                  return null;
                                },
                              ),

                              if (isCar) ...[
                                const SizedBox(height: 16),
                                _buildField(_plateCtrl, 'Car Plate Number',
                                    Icons.directions_car),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Parking Duration',
                                    labelStyle:
                                    GoogleFonts.montserrat(),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.red.shade700),
                                    ),
                                  ),
                                  value: _parkingDuration,
                                  items: _durationOptions
                                      .map((opt) => DropdownMenuItem(
                                    value: opt['value'],
                                    child: Text(opt['label']!,
                                        style: GoogleFonts
                                            .montserrat()),
                                  ))
                                      .toList(),
                                  onChanged: (v) => setState(
                                          () => _parkingDuration = v),
                                  validator: (v) => v == null
                                      ? 'Please select a duration'
                                      : null,
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    Colors.red.shade700,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(8)),
                                  ),
                                  onPressed:
                                  _submitting ? null : _submitForm,
                                  child: _submitting
                                      ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child:
                                    CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : Text(
                                    'Submit',
                                    style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight:
                                        FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Recent Tab ────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('visitors')
                      .where('residentId', isEqualTo: _residentId)
                      .orderBy('timestamp', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (ctx, snap) {
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Text('No recent requests',
                            style: GoogleFonts.montserrat(
                                color: Colors.grey)),
                      );
                    }
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final d =
                        docs[i].data()! as Map<String, dynamic>;
                        final status = d['status'] as String? ?? '';
                        Color statusColor;
                        Icon statusIcon;
                        switch (status) {
                          case 'approved':
                            statusColor = Colors.green;
                            statusIcon = const Icon(
                                Icons.check_circle,
                                color: Colors.green);
                            break;
                          case 'checked-in':
                            statusColor = Colors.blue;
                            statusIcon = const Icon(
                                Icons.close_fullscreen,
                                color: Colors.blue);
                            break;
                          case 'checked-out':
                            statusColor = Colors.blue;
                            statusIcon = const Icon(
                                Icons.open_in_browser,
                                color: Colors.blue);
                            break;
                          case 'denied':
                            statusColor = Colors.red;
                            statusIcon = const Icon(Icons.cancel,
                                color: Colors.red);
                            break;
                          default:
                            statusColor = Colors.orange;
                            statusIcon = const Icon(
                                Icons.hourglass_bottom,
                                color: Colors.orange);
                        }
                        final ts = (d['timestamp'] as Timestamp?)
                            ?.toDate();
                        final dateStr = ts == null
                            ? 'Unknown date'
                            : DateFormat('dd MMM yyyy')
                            .format(ts.toLocal());
                        final plate = d['vehiclePlate'] as String?;
                        final dur = d['parkingDuration'] as String?;
                        return Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 1,
                          child: ListTile(
                            leading: statusIcon,
                            title: Text(d['visitorName'] ?? '',
                                style:
                                GoogleFonts.montserrat(fontSize: 16)),
                            subtitle: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${d['entryType'].toString().toUpperCase()} • $dateStr',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 12),
                                ),
                                if (plate != null &&
                                    plate.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('Plate: $plate',
                                      style: GoogleFonts.montserrat(
                                          fontSize: 12)),
                                ],
                                if (dur != null) ...[
                                  const SizedBox(height: 4),
                                  Text('Duration: $dur',
                                      style: GoogleFonts.montserrat(
                                          fontSize: 12)),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Status: ${status.toUpperCase()}',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: statusColor),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 1,
          selectedItemColor: Colors.red.shade700,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
          unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
          onTap: (i) {
            switch (i) {
              case 0:
                GoRouter.of(context).go('/user');
                break;
              case 1:
              // already on visitor tab
                break;
              case 2:
                GoRouter.of(context).go('/user/bookFacility');
                break;
              case 3:
                GoRouter.of(context).go('/user/maintenanceRequest');
                break;
              case 4:
                GoRouter.of(context).go('/userprofile');
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_add), label: 'Visitor'),
            BottomNavigationBarItem(
                icon: Icon(Icons.event_available), label: 'Facility'),
            BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Maintain'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        TextInputType keyboard = TextInputType.text,
        List<TextInputFormatter>? inputFormatters,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(),
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red.shade700),
        ),
      ),
    );
  }
}
