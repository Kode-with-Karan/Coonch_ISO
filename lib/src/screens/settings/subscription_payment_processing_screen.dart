import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:provider/provider.dart';

import '../../services/api_service.dart';

class SubscriptionPaymentProcessResult {
  final bool success;
  final bool cancelled;
  final String message;
  final Map<String, dynamic>? subscription;

  const SubscriptionPaymentProcessResult({
    required this.success,
    this.cancelled = false,
    required this.message,
    this.subscription,
  });
}

class SubscriptionPaymentProcessingScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Map<String, dynamic> topic;

  const SubscriptionPaymentProcessingScreen({
    super.key,
    required this.plan,
    required this.topic,
  });

  @override
  State<SubscriptionPaymentProcessingScreen> createState() =>
      _SubscriptionPaymentProcessingScreenState();
}

class _SubscriptionPaymentProcessingScreenState
    extends State<SubscriptionPaymentProcessingScreen> {
  static const _activationRetryDelay = Duration(seconds: 1);
  static const _activationRetryCount = 5;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController(text: 'GB');

  bool _submitting = false;
  stripe.CardFieldInputDetails? _cardDetails;
  String? _cardError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _runPayment() async {
    if (_submitting) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
    });

    try {
      if (!(_cardDetails?.complete ?? false)) {
        setState(() {
          _cardError = 'Enter complete card details';
          _submitting = false;
        });
        return;
      }

      final api = Provider.of<ApiService>(context, listen: false);

      final intentRes =
          await api.createSubscriptionPaymentIntent(widget.plan['id'] as int);
      if (intentRes['success'] != 1) {
        _finish(
          SubscriptionPaymentProcessResult(
            success: false,
            message: intentRes['message']?.toString() ??
                'Unable to initiate payment. Please try again.',
          ),
        );
        return;
      }

      final data = Map<String, dynamic>.from(intentRes['data'] as Map? ?? {});
      final clientSecret = data['client_secret']?.toString() ?? '';
      final paymentIntentId = data['payment_intent_id']?.toString() ?? '';
      final publishableKey = data['publishable_key']?.toString() ?? '';

      if (clientSecret.isEmpty ||
          paymentIntentId.isEmpty ||
          publishableKey.isEmpty) {
        _finish(
          const SubscriptionPaymentProcessResult(
            success: false,
            message: 'Invalid payment session from server.',
          ),
        );
        return;
      }

      stripe.Stripe.publishableKey = publishableKey;
      await stripe.Stripe.instance.applySettings();

      final billingDetails = stripe.BillingDetails(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: stripe.Address(
          line1: _addressLine1Controller.text.trim(),
          line2: _addressLine2Controller.text.trim().isEmpty
              ? null
              : _addressLine2Controller.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty
              ? null
              : _stateController.text.trim(),
          postalCode: _postalCodeController.text.trim(),
          country: _countryController.text.trim().toUpperCase(),
        ),
      );

      final paymentMethod = await stripe.Stripe.instance.createPaymentMethod(
        params: stripe.PaymentMethodParams.card(
          paymentMethodData: stripe.PaymentMethodData(
            billingDetails: billingDetails,
          ),
        ),
      );

      final res = await _finalizeSubscription(
        api,
        paymentIntentId: paymentIntentId,
        paymentMethodId: paymentMethod.id,
      );

      if (res['success'] == 1) {
        _finish(
          SubscriptionPaymentProcessResult(
            success: true,
            message: res['message']?.toString() ??
                'Subscription activated successfully.',
            subscription: Map<String, dynamic>.from(
              (res['data'] as Map?)?['subscription'] as Map? ?? {},
            ),
          ),
        );
        return;
      }

      _finish(
        SubscriptionPaymentProcessResult(
          success: false,
          message: res['message']?.toString() ?? 'Subscription failed.',
        ),
      );
    } on stripe.StripeException catch (e) {
      _finish(
        SubscriptionPaymentProcessResult(
          success: false,
          cancelled: e.error.code == stripe.FailureCode.Canceled,
          message:
              e.error.localizedMessage ?? e.error.message ?? 'Payment failed.',
        ),
      );
    } on stripe.StripeConfigException catch (e) {
      _finish(
        SubscriptionPaymentProcessResult(
          success: false,
          message: e.message,
        ),
      );
    } on PlatformException catch (e) {
      _finish(
        SubscriptionPaymentProcessResult(
          success: false,
          message: e.message ?? 'Payment platform error. Please try again.',
        ),
      );
    } on ApiException catch (e) {
      _finish(
        SubscriptionPaymentProcessResult(
          success: false,
          message: _messageFromApiException(e),
        ),
      );
    } catch (e) {
      _finish(
        SubscriptionPaymentProcessResult(
          success: false,
          message: e.toString(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _finalizeSubscription(
    ApiService api, {
    required String paymentIntentId,
    String? paymentMethodId,
  }) async {
    Object? lastError;

    for (var attempt = 0; attempt < _activationRetryCount; attempt++) {
      try {
        return await api.subscribeToPlan(
          widget.plan['id'] as int,
          paymentIntentId: paymentIntentId,
          paymentMethodId: paymentMethodId,
        );
      } catch (error) {
        lastError = error;
        if (!_isTransientActivationError(error) ||
            attempt == _activationRetryCount - 1) {
          break;
        }
        await Future.delayed(_activationRetryDelay);
      }
    }

    try {
      final subscriptionRes = await api.getMySubscription();
      final data = Map<String, dynamic>.from(
        subscriptionRes['data'] as Map? ?? const <String, dynamic>{},
      );
      final subscription = Map<String, dynamic>.from(
        data['subscription'] as Map? ?? const <String, dynamic>{},
      );
      final hasActive = data['has_active_subscription'] == true;
      final planName = subscription['plan_name']?.toString();
      final currentPlanName = widget.plan['name']?.toString();

      if (hasActive &&
          planName != null &&
          currentPlanName != null &&
          planName == currentPlanName) {
        return {
          'success': 1,
          'message': 'Subscription activated successfully.',
          'data': {
            'subscription': subscription,
          },
        };
      }
    } catch (_) {
      // Ignore fallback errors and rethrow the original failure below.
    }

    if (lastError != null) {
      throw lastError;
    }

    throw Exception(
      'Payment completed, but subscription activation could not be confirmed.',
    );
  }

  bool _isTransientActivationError(Object error) {
    if (error is ApiException) {
      final body = error.body.toLowerCase();
      return error.code >= 500 ||
          body.contains('payment not completed') ||
          body.contains('processing') ||
          body.contains('requires_action') ||
          body.contains('requires_confirmation') ||
          body.contains('unable to verify payment');
    }
    return false;
  }

  String _messageFromApiException(ApiException error) {
    try {
      final decoded = jsonDecode(error.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        final detail = decoded['detail']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        if (detail != null && detail.isNotEmpty) {
          return detail;
        }
      }
    } catch (_) {
      // Ignore JSON parse failure and fall back to raw body below.
    }

    if (error.body.trim().isNotEmpty) {
      return error.body;
    }

    return 'Payment failed. Please try again.';
  }

  void _handleCardChanged(stripe.CardFieldInputDetails? details) {
    if (!mounted) return;
    setState(() {
      _cardDetails = details;
      if (details?.complete == true) {
        _cardError = null;
      }
    });
  }

  void _finish(SubscriptionPaymentProcessResult result) {
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final email = value.trim();
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final topicColor =
        widget.topic['color'] as Color? ?? const Color(0xFF1565C0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Payment Details',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan['name']?.toString() ?? 'Subscription Plan',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Amount: £${widget.plan['price']}/${widget.plan['plan_type']}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Contact details'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration('Full name'),
                  validator: (value) => _requiredValidator(value, 'Full name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration('Email address'),
                  validator: _emailValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s'))
                  ],
                  decoration: _inputDecoration('Phone number (optional)'),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Billing address'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressLine1Controller,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration('Address line 1'),
                  validator: (value) =>
                      _requiredValidator(value, 'Address line 1'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressLine2Controller,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration('Address line 2 (optional)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration('City'),
                        validator: (value) => _requiredValidator(value, 'City'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration('State (optional)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _postalCodeController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration('Postal code'),
                        validator: (value) =>
                            _requiredValidator(value, 'Postal code'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _countryController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z]')),
                          LengthLimitingTextInputFormatter(2),
                        ],
                        decoration: _inputDecoration('Country (ISO code)'),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.length != 2) {
                            return 'Use 2-letter code';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle('Card details'),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _cardError == null
                          ? Colors.grey.shade300
                          : Colors.red.shade300,
                    ),
                  ),
                  child: stripe.CardField(
                    enablePostalCode: false,
                    dangerouslyGetFullCardDetails: false,
                    onCardChanged: _handleCardChanged,
                  ),
                ),
                if (_cardError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _cardError!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, color: topicColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Enter the card above. Your card details are tokenized securely by Stripe inside the app and are not stored by Coonch.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _runPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: topicColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Pay Securely',
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
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.3),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
