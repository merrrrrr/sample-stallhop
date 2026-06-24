import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/constants.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Phase 4 wraps this in a MultiProvider once auth/role providers exist.
  // (MultiProvider asserts on an empty providers list, so it is added then.)
  runApp(const StallHopApp());
}

class StallHopApp extends StatelessWidget {
  const StallHopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: Center(
          child: Text(
            AppConstants.appName,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
