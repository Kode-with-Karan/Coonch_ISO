import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import 'subscription_checkout_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _activeSubscriptions = [];
  Map<String, dynamic>? _currentSubscription;
  Map<String, dynamic>? _latestSubscription;
  bool _loading = true;
  String _selectedTopic = 'all';

  final List<Map<String, dynamic>> _topics = [
    {
      'key': 'all',
      'label': 'All Access',
      'icon': Icons.diamond,
      'color': const Color(0xFF1565C0)
    },
    {
      'key': 'entertainment',
      'label': 'Entertainment',
      'icon': Icons.movie,
      'color': const Color(0xFF1976D2)
    },
    {
      'key': 'infotainment',
      'label': 'Infotainment',
      'icon': Icons.info,
      'color': const Color(0xFF2196F3)
    },
    {
      'key': 'education',
      'label': 'Education',
      'icon': Icons.school,
      'color': const Color(0xFF42A5F5)
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);

      final plansRes = await api.getSubscriptionPlans();
      final subRes = await api.getMySubscription();

      if (mounted) {
        final responseData = subRes['data'] as Map<String, dynamic>?;
        final activeSubscriptions =
            _toMapList(responseData?['active_subscriptions']);

        setState(() {
          _plans = plansRes;
          if (responseData != null) {
            final current =
                responseData['subscription'] as Map<String, dynamic>?;
            final latest =
                responseData['latest_subscription'] as Map<String, dynamic>?;

            _currentSubscription =
                _isMeaningfulSubscription(current) ? current : null;
            _latestSubscription =
                _isMeaningfulSubscription(latest) ? latest : null;
            _activeSubscriptions = activeSubscriptions
                .where((sub) => _isMeaningfulSubscription(sub))
                .toList();
            if (_activeSubscriptions.isEmpty && _currentSubscription != null) {
              _activeSubscriptions = [
                Map<String, dynamic>.from(_currentSubscription!)
              ];
            }
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        Provider.of<NotificationService>(context, listen: false)
            .showError('Failed to load subscription data');
      }
    }
  }

  List<Map<String, dynamic>> _toMapList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  bool _isMeaningfulSubscription(Map<String, dynamic>? subscription) {
    if (subscription == null || subscription.isEmpty) return false;

    final planName = subscription['plan_name']?.toString().trim();
    final planType = subscription['plan_type']?.toString().trim();
    final planTopic = subscription['plan_topic']?.toString().trim();

    return (planName != null && planName.isNotEmpty) ||
        (planType != null && planType.isNotEmpty) ||
        (planTopic != null && planTopic.isNotEmpty);
  }

  bool _isSubscriptionActive(Map<String, dynamic> subscription) {
    final flag = subscription['is_active'];
    if (flag is bool) return flag;
    final status = subscription['status']?.toString().toLowerCase();
    if (status == 'active') return true;
    if (flag is num) return flag != 0;
    if (flag != null) {
      final normalized = flag.toString().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return false;
  }

  bool _isPlanActive(Map<String, dynamic> plan) {
    final planName = plan['name']?.toString().trim().toLowerCase();
    final planType = plan['plan_type']?.toString().trim().toLowerCase();
    final planTopic = plan['topic']?.toString().trim().toLowerCase();

    return _activeSubscriptions.any((subscription) {
      if (!_isSubscriptionActive(subscription)) return false;

      final subName =
          subscription['plan_name']?.toString().trim().toLowerCase();
      final subType =
          subscription['plan_type']?.toString().trim().toLowerCase();
      final subTopic =
          subscription['plan_topic']?.toString().trim().toLowerCase();

      if (planName != null && subName != null && planName == subName) {
        return true;
      }

      return planType != null &&
          planTopic != null &&
          subType == planType &&
          subTopic == planTopic;
    });
  }

  List<Map<String, dynamic>> _getPlansForTopic(String topic) {
    if (topic == 'all') return _plans;
    return _plans.where((plan) => plan['topic'] == topic).toList();
  }

  Future<void> _openCheckout(
    Map<String, dynamic> plan,
    Map<String, dynamic> topic,
  ) async {
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SubscriptionCheckoutScreen(
          plan: Map<String, dynamic>.from(plan),
          topic: Map<String, dynamic>.from(topic),
        ),
      ),
    );

    if (success == true && mounted) {
      Provider.of<NotificationService>(context, listen: false)
          .showSuccess('Subscription activated successfully!');
      _loadData();
    }
  }

  String _getPlanTypeLabel(String planType) {
    switch (planType) {
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return planType;
    }
  }

  String _formatSubscriptionDate(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';
    try {
      final date = DateTime.parse(raw).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios)),
        title:
            const Text('Subscriptions', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? _buildNoPlansView()
              : Column(
                  children: [
                    _buildTopicSelector(),
                    Expanded(child: _buildPlansList()),
                  ],
                ),
    );
  }

  Widget _buildTopicSelector() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _topics.length,
        itemBuilder: (context, index) {
          final topic = _topics[index];
          final isSelected = _selectedTopic == topic['key'];
          final color = topic['color'] as Color;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedTopic = topic['key'] as String);
                }
              },
              avatar: Icon(
                topic['icon'] as IconData,
                size: 18,
                color: isSelected ? Colors.white : color,
              ),
              label: Text(topic['label'] as String),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: Colors.grey.shade100,
              selectedColor: color,
              side: BorderSide(color: isSelected ? color : Colors.transparent),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoPlansView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.subscriptions_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No subscription plans available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Please check back later'),
        ],
      ),
    );
  }

  Widget _buildPlansList() {
    final topicPlans = _getPlansForTopic(_selectedTopic);
    final topic = _topics.firstWhere((t) => t['key'] == _selectedTopic);

    if (topicPlans.isEmpty) {
      return _buildEmptyTopicState(topic);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_activeSubscriptions.isNotEmpty ||
              _latestSubscription != null) ...[
            _buildCurrentSubscriptionSection(),
            const SizedBox(height: 20),
          ],
          _buildTopicHeader(topic),
          const SizedBox(height: 16),
          ...topicPlans.map((plan) => _buildPlanCard(plan, topic)),
          const SizedBox(height: 24),
          _buildInfoSection(topic),
        ],
      ),
    );
  }

  Widget _buildEmptyTopicState(Map<String, dynamic> topic) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(topic['icon'] as IconData,
              size: 64, color: (topic['color'] as Color).withAlpha(128)),
          const SizedBox(height: 16),
          Text('No ${topic['label']} plans available',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Check back later for new plans'),
        ],
      ),
    );
  }

  Widget _buildCurrentSubscriptionSection() {
    final cards = <Widget>[];
    final active = _activeSubscriptions.where(_isSubscriptionActive).toList();

    if (active.isNotEmpty) {
      cards.add(
        Text(
          active.length == 1
              ? 'Your Active Plan'
              : 'Your Active Plans (${active.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
      cards.add(const SizedBox(height: 12));
      cards.addAll(active.map((sub) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCurrentSubscriptionCard(sub),
          )));
    } else if (_latestSubscription != null) {
      cards.add(
        _buildCurrentSubscriptionCard(
          _latestSubscription!,
          titleOverride: 'Latest Subscription',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cards,
    );
  }

  Widget _buildCurrentSubscriptionCard(
    Map<String, dynamic> sub, {
    String? titleOverride,
  }) {
    final isActive = _isSubscriptionActive(sub);
    final expiresAt = _formatSubscriptionDate(sub['expires_at']);
    final title = titleOverride ??
        (isActive ? 'Active Subscription' : 'Subscription Expired');
    final subtitle = isActive
        ? '${sub['plan_name']} • ${sub['days_remaining']} days remaining${expiresAt.isNotEmpty ? ' • Expires $expiresAt' : ''}'
        : '${sub['plan_name']} expired${expiresAt.isNotEmpty ? ' on $expiresAt' : ''}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [const Color(0xFF1976D2), const Color(0xFF1565C0)]
              : [const Color(0xFFF57C00), const Color(0xFFE65100)],
        ),
        boxShadow: [
          BoxShadow(
              color:
                  (isActive ? const Color(0xFF1565C0) : const Color(0xFFE65100))
                      .withAlpha(51),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withAlpha(51), shape: BoxShape.circle),
            child: Icon(
              isActive ? Icons.check_circle : Icons.schedule,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(color: Colors.white.withAlpha(230))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicHeader(Map<String, dynamic> topic) {
    final color = topic['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(204), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withAlpha(77),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(topic['icon'] as IconData, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(topic['label'] as String,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 12),
          Text(_getTopicDescription(topic['key'] as String),
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeatureChip(icon: Icons.play_circle, label: 'Unlimited Access'),
              _FeatureChip(icon: Icons.block, label: 'Ad-Free'),
              _FeatureChip(icon: Icons.download, label: 'Offline'),
            ],
          ),
        ],
      ),
    );
  }

  String _getTopicDescription(String topicKey) {
    switch (topicKey) {
      case 'all':
        return 'Get access to all content across Entertainment, Infotainment, and Education.';
      case 'entertainment':
        return 'Enjoy unlimited access to music videos, short films, movies, and all entertainment content.';
      case 'infotainment':
        return 'Stay informed with documentaries, news, interviews, and engaging informational content.';
      case 'education':
        return 'Learn new skills with courses, tutorials, lectures, and educational materials.';
      default:
        return 'Get access to premium content';
    }
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, Map<String, dynamic> topic) {
    final isActive = _isPlanActive(plan);
    final isBest = plan['plan_type'] == 'yearly';
    final topicColor = topic['color'] as Color;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isBest ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            isBest ? BorderSide(color: topicColor, width: 2) : BorderSide.none,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isBest
              ? LinearGradient(
                  colors: [topicColor.withAlpha(26), topicColor.withAlpha(13)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: _getPlanColor(plan['plan_type']).withAlpha(26),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(_getPlanTypeLabel(plan['plan_type']),
                      style: TextStyle(
                          color: _getPlanColor(plan['plan_type']),
                          fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (isBest)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('BEST VALUE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Active',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(plan['name'] ?? 'Subscription Plan',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('£${plan['price']}',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: topicColor)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('/${plan['plan_type']}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                ),
                if (plan['plan_type'] == 'yearly') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFBBDEFB),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('Save ${_calculateSavings(plan)}%',
                        style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _buildDefaultFeatures(topicColor),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: isActive
                  ? const OutlinedButton(
                      onPressed: null,
                      child:
                          Text('Current Plan', style: TextStyle(fontSize: 16)))
                  : ElevatedButton(
                      onPressed: () => _showConfirmDialog(plan, topic),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: topicColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: isBest ? 4 : 0,
                      ),
                      child: const Text('Subscribe Now',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateSavings(Map<String, dynamic> yearlyPlan) {
    final weeklyPlans = _plans
        .where((p) =>
            p['plan_type'] == 'weekly' && p['topic'] == yearlyPlan['topic'])
        .toList();
    if (weeklyPlans.isEmpty) return 0;
    final weeklyPrice =
        double.tryParse(weeklyPlans.first['price']?.toString() ?? '0') ?? 0;
    final yearlyPrice =
        double.tryParse(yearlyPlan['price']?.toString() ?? '0') ?? 0;
    final weeklyTotal = weeklyPrice * 52;
    if (weeklyTotal == 0) return 0;
    return ((weeklyTotal - yearlyPrice) / weeklyTotal * 100).round();
  }

  Widget _buildDefaultFeatures(Color color) {
    final features = [
      'Unlimited content access',
      'Ad-free viewing',
      'Download for offline',
      'Premium content included'
    ];
    return Column(
      children: features
          .map((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(Icons.check_circle, color: color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(feature)),
                ]),
              ))
          .toList(),
    );
  }

  Color _getPlanColor(String planType) {
    switch (planType) {
      case 'weekly':
        return const Color(0xFF64B5F6);
      case 'monthly':
        return const Color(0xFF2196F3);
      case 'yearly':
        return const Color(0xFF1565C0);
      default:
        return AppTheme.primary;
    }
  }

  void _showConfirmDialog(
      Map<String, dynamic> plan, Map<String, dynamic> topic) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(topic['icon'] as IconData, color: topic['color'] as Color),
          const SizedBox(width: 8),
          const Text('Confirm Subscription')
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subscribe to ${plan['name']}?',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Price: £${plan['price']}/${plan['plan_type']}',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: (topic['color'] as Color).withAlpha(26),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.check, color: topic['color'] as Color),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        "You'll get unlimited access to ${topic['label']} content",
                        style: TextStyle(color: topic['color'] as Color)))
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openCheckout(plan, topic);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: topic['color'] as Color),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> topic) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text('About ${topic['label']} Subscription',
                style: const TextStyle(fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 12),
          _buildInfoRow(
              Icons.card_membership, 'Subscription renews automatically'),
          _buildInfoRow(Icons.cancel, 'Cancel anytime from settings'),
          _buildInfoRow(Icons.support_agent, '24/7 customer support available'),
          _buildInfoRow(Icons.lock, 'Secure payment processing'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13)))
      ]),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12))
      ]),
    );
  }
}
