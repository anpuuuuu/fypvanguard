// lib/user/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl  = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailCtrl.text.trim();
    final pwd   = passCtrl.text.trim();
    if (email.isEmpty || pwd.isEmpty) {
      _showMsg('Please enter your email and password');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pwd);
      GoRouter.of(context).go('/loading');
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'User does not exist';
          break;
        case 'wrong-password':
          msg = 'Wrong password';
          break;
        default:
          msg = 'Login failed: ${e.message}';
      }
      _showMsg(msg);
    } catch (e) {
      _showMsg('Login error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        title: Text(
          'Vanguard',
          style: GoogleFonts.montserrat(
              fontSize: 20, fontWeight: FontWeight.bold
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ——— Your Logo ———
              SizedBox(
                height: 150,
                child: Image.asset(
                  'assets/logo.jpg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Sign In',
                style: GoogleFonts.montserrat(
                    fontSize: 24, fontWeight: FontWeight.w600
                ),
              ),
              const SizedBox(height: 32),

              // ——— Email Field ———
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: GoogleFonts.montserrat(),
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // ——— Password Field ———
              TextField(
                controller: passCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: GoogleFonts.montserrat(),
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),

              // ——— Login Button ———
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white
                    ),
                  )
                      : Text(
                    'Login',
                    style: GoogleFonts.montserrat(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: Colors.white
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ——— Register Link ———
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => GoRouter.of(context).go('/register'),
                child: Text(
                  'Register as Owner',
                  style: GoogleFonts.montserrat(
                      color: Colors.red.shade700, fontSize: 14
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
