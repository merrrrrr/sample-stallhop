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
import '../view_model/earnings_vm.dart';

class VendorEarningsPage extends StatelessWidget {
  const VendorEarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EarningsViewModel(),
      child: const _EarningsView(),
    );
  }
}

class _EarningsView extends StatelessWidget {
  const _EarningsView();

  Future<void> _withdraw(BuildContext context, int balance) async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw earnings'),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: 'RM ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final cents = rmToCents(controller.text);
              Navigator.pop(ctx, cents);
            },
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;
    if (amount > balance) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Amount exceeds your balance.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final vm = context.read<EarningsViewModel>();
    final uid = context.read<AuthViewModel>().currentUser!.uid;
    final ok = await vm.withdraw(uid, amount);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Withdrawal successful' : (vm.error ?? 'Failed')),
          backgroundColor: ok ? null : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EarningsViewModel>();
    final user = context.watch<AuthViewModel>().currentUser;
    final balance = user?.walletBalance ?? 0;
    final uid = user?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WalletBalanceCard(
            balanceCents: balance,
            label: 'Available earnings',
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.account_balance),
            label: const Text('Withdraw'),
            onPressed: vm.isProcessing
                ? null
                : () => _withdraw(context, balance),
          ),
          const SizedBox(height: 24),
          Text('History', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          if (uid != null)
            StreamBuilder<List<WalletTransaction>>(
              stream: vm.earnings(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final txns = snapshot.data ?? [];
                if (txns.isEmpty) {
                  return const EmptyState(
                    icon: Icons.payments_outlined,
                    title: 'No earnings yet',
                    subtitle: 'Completed orders will show up here.',
                  );
                }
                return Column(
                  children: [for (final t in txns) _EarningTile(txn: t)],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EarningTile extends StatelessWidget {
  final WalletTransaction txn;
  const _EarningTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isWithdrawal = txn.type == AppConstants.txnWithdrawal;
    final isReversal = txn.type == AppConstants.txnRefund;
    final isCredit = !isWithdrawal && !isReversal;
    final color = isCredit ? AppColors.teal : AppColors.navy;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          isWithdrawal
              ? Icons.account_balance
              : isReversal
                  ? Icons.undo
                  : Icons.payments,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        txn.description.isEmpty ? txn.type : txn.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle:
          Text(formatDateTime(txn.createdAt), style: AppTextStyles.caption),
      trailing: Text(
        '${isCredit ? '+' : '-'}${centsToRM(txn.amount)}',
        style: AppTextStyles.title.copyWith(color: color),
      ),
    );
  }
}
