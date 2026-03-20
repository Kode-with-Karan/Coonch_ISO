import 'package:flutter/material.dart';

class SubscriptionPaymentFailedScreen extends StatelessWidget {
  final Map<String, dynamic> plan;
  final String message;
  final bool cancelled;

  const SubscriptionPaymentFailedScreen({
    super.key,
    required this.plan,
    required this.message,
    this.cancelled = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = cancelled ? 'Payment Cancelled' : 'Payment Failed';
    final accent =
        cancelled ? const Color(0xFFF9A825) : const Color(0xFFC62828);
    final bg = cancelled ? const Color(0xFFFFF8E1) : const Color(0xFFFFEBEE);
    final icon = cancelled ? Icons.info_outline : Icons.error_outline;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: accent, size: 54),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
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
                    _detailRow(
                        'Plan', plan['name']?.toString() ?? 'Subscription'),
                    const SizedBox(height: 10),
                    _detailRow(
                        'Amount', '£${plan['price']}/${plan['plan_type']}'),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop('retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
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
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
