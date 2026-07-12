import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../view_model/auth_view_model.dart';

/// Shown after a brand-new Google sign-in to capture the user's role before
/// their StallHop account document is created.
class ChooseRolePage extends StatefulWidget {
  const ChooseRolePage({super.key});

  @override
  State<ChooseRolePage> createState() => _ChooseRolePageState();
}

class _ChooseRolePageState extends State<ChooseRolePage> {
  String _role = AppConstants.roleCustomer;
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final vm = context.read<AuthViewModel>();
    final ok = await vm.completeRoleSelection(
      role: _role,
      phone: _phoneController.text,
    );
    if (!ok && mounted && vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error!), backgroundColor: AppColors.error),
      );
    }
    // On success the AuthGate routes to the role home automatically.
  }

  static const _roles = [
    (
      AppConstants.roleCustomer,
      'Customer',
      'Browse stalls and order food',
      Icons.shopping_bag_outlined,
    ),
    (
      AppConstants.roleVendor,
      'Vendor',
      'Run a stall and manage orders',
      Icons.storefront_outlined,
    ),
    (
      AppConstants.roleAdmin,
      'Admin',
      'Oversee the venue',
      Icons.admin_panel_settings_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your role'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => context.read<AuthViewModel>().logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('How will you use StallHop?', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              for (final (role, title, subtitle, icon) in _roles) ...[
                _RoleCard(
                  title: title,
                  subtitle: subtitle,
                  icon: icon,
                  selected: _role == role,
                  onTap: () => setState(() => _role = role),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: vm.isLoading ? null : _continue,
                child: vm.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.orangeLight : AppColors.white,
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.divider,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  selected ? AppColors.orange : AppColors.offWhite,
              child: Icon(icon,
                  color: selected ? AppColors.white : AppColors.warmGrey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.title),
                  Text(subtitle, style: AppTextStyles.bodySecondary),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.orange),
          ],
        ),
      ),
    );
  }
}
