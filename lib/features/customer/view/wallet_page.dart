import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transaction.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/wallet_balance_card.dart';
import '../../auth/view_model/auth_view_model.dart';
import '../view_model/wallet_vm.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WalletViewModel(),
      child: const _WalletView(),
    );
  }
}

class _WalletView extends StatefulWidget {
  const _WalletView();

  @override
  State<_WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<_WalletView> {
  int _selectedAmount = AppConstants.topUpPresetsCents.first;

  Future<void> _topUp() async {
    final vm = context.read<WalletViewModel>();
    final uid = context.read<AuthViewModel>().currentUser?.uid;
    if (uid == null) return;
    final ok = await vm.topUp(uid, _selectedAmount);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Topped up ${centsToRM(_selectedAmount)}'
            : (vm.error ?? 'Top-up failed')),
        backgroundColor: ok ? null : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WalletViewModel>();
    final user = context.watch<AuthViewModel>().currentUser;
    final uid = user?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WalletBalanceCard(balanceCents: user?.walletBalance ?? 0),
          const SizedBox(height: 24),
          Text('Top up', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final amount in AppConstants.topUpPresetsCents)
                ChoiceChip(
                  label: Text(centsToRM(amount)),
                  selected: _selectedAmount == amount,
                  onSelected: (_) =>
                      setState(() => _selectedAmount = amount),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: const [
                Icon(Icons.credit_card, color: AppColors.warmGrey),
                SizedBox(width: 12),
                Text('Mock card •••• 4242'),
                Spacer(),
                Icon(Icons.check_circle, color: AppColors.teal, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: vm.isProcessing ? null : _topUp,
            child: vm.isProcessing
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('Top up ${centsToRM(_selectedAmount)}'),
          ),
          const SizedBox(height: 28),
          Text('Transactions', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          if (uid != null)
            StreamBuilder<List<WalletTransaction>>(
              stream: vm.transactions(uid),
              builder: (context, snapshot) {
                final txns = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (txns.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet',
                  );
                }
                return Column(
                  children: [
                    for (final txn in txns) _TransactionTile(txn: txn),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction txn;
  const _TransactionTile({required this.txn});

  bool get _isCredit => const [
        AppConstants.txnTopUp,
        AppConstants.txnRefund,
        AppConstants.txnEarning,
      ].contains(txn.type);

  @override
  Widget build(BuildContext context) {
    final color = _isCredit ? AppColors.teal : AppColors.navy;
    final sign = _isCredit ? '+' : '-';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          _isCredit ? Icons.south_west : Icons.north_east,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        txn.description.isEmpty ? txn.type : txn.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(formatDateTime(txn.createdAt),
          style: AppTextStyles.caption),
      trailing: Text(
        '$sign${centsToRM(txn.amount)}',
        style: AppTextStyles.title.copyWith(color: color),
      ),
    );
  }
}
