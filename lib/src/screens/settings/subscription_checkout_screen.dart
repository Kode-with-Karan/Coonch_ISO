import 'package:flutter/material.dart';

import 'subscription_payment_failed_screen.dart';
import 'subscription_payment_processing_screen.dart';
import 'subscription_payment_success_screen.dart';

class SubscriptionCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Map<String, dynamic> topic;

  const SubscriptionCheckoutScreen({
    super.key,
    required this.plan,
    required this.topic,
  });

  @override
  State<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState
    extends State<SubscriptionCheckoutScreen> {
  bool _openingPayment = false;

  List<String> get _features {
    final raw = widget.plan['features'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [
      'Unlimited access to premium content',
      'Secure payment via Stripe',
      'Instant plan activation after payment',
    ];
  }

  Future<void> _startPaymentFlow() async {
    if (_openingPayment) return;
    setState(() => _openingPayment = true);

    final result =
        await Navigator.of(context).push<SubscriptionPaymentProcessResult>(
      MaterialPageRoute(
        builder: (_) => SubscriptionPaymentProcessingScreen(
          plan: widget.plan,
          topic: widget.topic,
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _openingPayment = false);

    if (result == null) {
      return;
    }

    if (result.success) {
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SubscriptionPaymentSuccessScreen(
            plan: widget.plan,
            subscription: result.subscription,
          ),
        ),
      );
      if (done == true && mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    final retry = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SubscriptionPaymentFailedScreen(
          plan: widget.plan,
          message: result.message,
          cancelled: result.cancelled,
        ),
      ),
    );

    if (retry == 'retry' && mounted) {
      _startPaymentFlow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicColor =
        widget.topic['color'] as Color? ?? const Color(0xFF1565C0);
    final topicLabel = widget.topic['label']?.toString() ?? 'Subscription';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed:
              _openingPayment ? null : () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [topicColor.withAlpha(230), topicColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: topicColor.withAlpha(70),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topicLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.plan['name']?.toString() ?? 'Subscription Plan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '£${widget.plan['price']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '/${widget.plan['plan_type']}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _sectionCard(
                title: 'What you will get',
                child: Column(
                  children: _features
                      .map(
                        (feature) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle,
                                  size: 20, color: topicColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Payment details',
                child: Column(
                  children: [
                    _detailRow('Amount', '£${widget.plan['price']}'),
                    const SizedBox(height: 12),
                    _detailRow(
                        'Duration', '${widget.plan['duration_days']} days'),
                    const SizedBox(height: 12),
                    _detailRow('Billing', '${widget.plan['plan_type']} plan'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, color: topicColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enter your card details securely inside the app to complete your subscription.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _openingPayment ? null : _startPaymentFlow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: topicColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _openingPayment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue to Card Details',
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

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          child,
        ],
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
