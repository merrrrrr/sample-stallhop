import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/venue_config.dart';
import '../../auth/view_model/auth_view_model.dart';
import '../repository/venue_config_repository.dart';
import 'announcements_page.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _repository = VenueConfigRepository();
  late Future<int> _topUpTotal;

  @override
  void initState() {
    super.initState();
    _topUpTotal = _repository.totalTopUps();
  }

  Future<void> _editCommission(double current) async {
    final controller = TextEditingController(
      text: (current * 100).toStringAsFixed(0),
    );
    final percent = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Commission rate'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Percent',
            suffixText: '%',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (percent == null || percent < 0 || percent > 100) return;
    await _repository.updateCommission(percent / 100);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Commission set to ${percent.toStringAsFixed(0)}%')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthViewModel>().logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Venue', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          StreamBuilder<VenueConfig?>(
            stream: _repository.watchConfig(),
            builder: (context, snapshot) {
              final config = snapshot.data;
              final rate = config?.defaultCommission ?? 0.10;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.percent,
                      color: AppColors.orange),
                  title: const Text('Commission rate'),
                  subtitle: Text('${(rate * 100).toStringAsFixed(0)}% '
                      'of each order subtotal'),
                  trailing: TextButton(
                    onPressed: () => _editCommission(rate),
                    child: const Text('Edit'),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Wallet monitoring', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Card(
            child: FutureBuilder<int>(
              future: _topUpTotal,
              builder: (context, snapshot) {
                return ListTile(
                  leading: const Icon(Icons.account_balance_wallet,
                      color: AppColors.teal),
                  title: const Text('Total customer top-ups'),
                  subtitle: Text(
                    snapshot.connectionState == ConnectionState.waiting
                        ? 'Calculating…'
                        : centsToRM(snapshot.data ?? 0),
                    style: AppTextStyles.title,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {
                      _topUpTotal = _repository.totalTopUps();
                    }),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text('Communication', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.campaign_outlined,
                  color: AppColors.orange),
              title: const Text('Announcements'),
              subtitle: const Text('Broadcast a message to all users'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
