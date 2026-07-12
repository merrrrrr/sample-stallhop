import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/services/notification_coordinator.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/constants.dart';
import 'features/auth/view/choose_role_page.dart';
import 'features/auth/view/login_page.dart';
import 'features/auth/view_model/auth_view_model.dart';
import 'features/customer/view_model/cart_vm.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final notificationService = NotificationService();
  await notificationService.init();

  // In-app notifications follow the signed-in user: listeners start on
  // login and stop on logout (see NotificationCoordinator).
  final authViewModel = AuthViewModel();
  final notificationCoordinator =
      NotificationCoordinator(notifications: notificationService);
  authViewModel.addListener(
    () => notificationCoordinator.sync(authViewModel.currentUser),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authViewModel),
        ChangeNotifierProvider(create: (_) => CartViewModel()),
      ],
      child: const StallHopApp(),
    ),
  );
}

class StallHopApp extends StatelessWidget {
  const StallHopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

/// Routes between the splash, login, role-selection, and the role home based on
/// [AuthViewModel.status].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    switch (vm.status) {
      case AuthStatus.unknown:
        return const _SplashScreen();
      case AuthStatus.unauthenticated:
        return const LoginPage();
      case AuthStatus.needsRoleSelection:
        return const ChooseRolePage();
      case AuthStatus.authenticated:
        return getHomeForRole(vm.currentUser!.role);
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.orange,
              ),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
