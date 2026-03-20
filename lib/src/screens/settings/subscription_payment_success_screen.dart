import 'package:flutter/material.dart';

class SubscriptionPaymentSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> plan;
  final Map<String, dynamic>? subscription;

  const SubscriptionPaymentSuccessScreen({
    super.key,
    required this.plan,
    this.subscription,
  });

  @override
  Widget build(BuildContext context) {
    final planName = subscription?['plan_name']?.toString() ??
        plan['name']?.toString() ??
        'Subscription Plan';
    final daysRemaining = subscription?['days_remaining']?.toString();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Payment Successful',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF2E7D32),
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Subscription Activated',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Your payment has been completed and your plan is now active.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('Plan', planName),
                    const SizedBox(height: 12),
                    _detailRow(
                        'Amount', '£${plan['price']}/${plan['plan_type']}'),
                    if (daysRemaining != null) ...[
                      const SizedBox(height: 12),
                      _detailRow('Days remaining', daysRemaining),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
