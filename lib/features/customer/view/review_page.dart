import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/order.dart';
import '../view_model/review_vm.dart';

class ReviewPage extends StatelessWidget {
  final FoodOrder order;
  const ReviewPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReviewViewModel()..checkExisting(order.orderId),
      child: _ReviewView(order: order),
    );
  }
}

class _ReviewView extends StatefulWidget {
  final FoodOrder order;
  const _ReviewView({required this.order});

  @override
  State<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<_ReviewView> {
  double _rating = 5;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vm = context.read<ReviewViewModel>();
    final ok = await vm.submit(
      order: widget.order,
      rating: _rating.round(),
      comment: _commentController.text,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your review!')),
      );
      Navigator.of(context).pop();
    } else if (vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error!), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Leave a review')),
      body: vm.alreadyReviewed
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('You have already reviewed this order.'),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.order.stallName, style: AppTextStyles.h3,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('How was your order?',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Center(
                    child: RatingBar.builder(
                      initialRating: _rating,
                      minRating: 1,
                      itemCount: 5,
                      itemSize: 44,
                      glow: false,
                      itemBuilder: (_, _) =>
                          const Icon(Icons.star, color: AppColors.orange),
                      onRatingUpdate: (r) => setState(() => _rating = r),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Share details of your experience (optional)',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: vm.isSubmitting ? null : _submit,
                    child: vm.isSubmitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Submit review'),
                  ),
                ],
              ),
            ),
    );
  }
}
