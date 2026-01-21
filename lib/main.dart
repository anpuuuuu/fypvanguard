import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'main/router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SecurePassApp());
}

class SecurePassApp extends StatelessWidget {
  const SecurePassApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Vanguard',
      routerConfig: appRouter,
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
    );
  }
}
