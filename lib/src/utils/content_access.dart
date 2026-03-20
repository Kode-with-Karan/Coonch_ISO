String _stringValue(dynamic value) => value?.toString() ?? '';

bool? _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final normalized = _stringValue(value).trim().toLowerCase();
  if (normalized.isEmpty) return null;
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return null;
}

List<Map<String, dynamic>> activeSubscriptionsFromContent(
    Map<String, dynamic>? content) {
  final raw = content?['active_subscriptions'];
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }
  return const [];
}

String _requiredTopicKey(Map<String, dynamic>? content) {
  final topic = _stringValue(content?['required_subscription_topic'])
      .trim()
      .toLowerCase();
  if (topic.isNotEmpty) return topic;
  return _stringValue(content?['topic']).trim().toLowerCase();
}

bool _subscriptionMatchesTopic(
    Map<String, dynamic>? subscription, String topic) {
  if (subscription == null) return false;
  if (topic.isEmpty) return false;

  final subTopic =
      _stringValue(subscription['plan_topic']).trim().toLowerCase();
  final subActive = _toBool(subscription['is_active']) ??
      _stringValue(subscription['status']).trim().toLowerCase() == 'active';

  if (!subActive) return false;
  if (subTopic == 'all') return true;
  return subTopic == topic;
}

bool _hasMatchingActiveSubscription(Map<String, dynamic>? content) {
  if (content == null) return false;

  final topic = _requiredTopicKey(content);
  if (topic.isEmpty) return false;

  final primary = activeSubscriptionFromContent(content);
  if (_subscriptionMatchesTopic(primary, topic)) {
    return true;
  }

  final subscriptions = activeSubscriptionsFromContent(content);
  for (final subscription in subscriptions) {
    if (_subscriptionMatchesTopic(subscription, topic)) {
      return true;
    }
  }

  return false;
}

bool isPremiumContent(Map<String, dynamic>? content) {
  if (content == null) return false;
  final premiumFlag = content['is_premium'];
  if (premiumFlag == true) return true;
  final freeFlag = content['free'];
  final price = double.tryParse(_stringValue(content['price'])) ?? 0;
  final result = freeFlag != true && price > 0;
  // Debug logging
  print(
      '[ACCESS] isPremiumContent: is_premium=$premiumFlag, free=$freeFlag, price=$price => $result');
  return result;
}

bool canAccessContent(Map<String, dynamic>? content) {
  if (content == null) return true;
  final canAccess = content['can_access'];
  final parsedCanAccess = _toBool(canAccess);
  // Debug logging
  print(
      '[ACCESS] canAccessContent: can_access=$canAccess (type: ${canAccess.runtimeType})');

  if (parsedCanAccess != null) {
    return parsedCanAccess;
  }

  if (_hasMatchingActiveSubscription(content)) {
    print(
        '[ACCESS] canAccessContent: inferred access from active subscription');
    return true;
  }

  final fallback = !isPremiumContent(content);
  print(
      '[ACCESS] canAccessContent: falling back to !isPremiumContent => $fallback');
  return fallback;
}

bool isLockedContent(Map<String, dynamic>? content) {
  final premium = isPremiumContent(content);
  final canAccess = canAccessContent(content);
  final locked = premium && !canAccess;
  print(
      '[ACCESS] isLockedContent: premium=$premium, canAccess=$canAccess => locked=$locked');
  return locked;
}

Map<String, dynamic>? activeSubscriptionFromContent(
    Map<String, dynamic>? content) {
  final raw = content?['active_subscription'];
  final direct = raw is Map<String, dynamic>
      ? raw
      : raw is Map
          ? Map<String, dynamic>.from(raw)
          : null;
  if (direct != null) {
    return direct;
  }

  final subscriptions = activeSubscriptionsFromContent(content);
  if (subscriptions.isNotEmpty) {
    return subscriptions.first;
  }
  return null;
}

Map<String, dynamic>? latestSubscriptionFromContent(
    Map<String, dynamic>? content) {
  final raw = content?['latest_subscription'];
  return raw is Map<String, dynamic>
      ? raw
      : raw is Map
          ? Map<String, dynamic>.from(raw)
          : null;
}

String requiredPlanTopicLabel(Map<String, dynamic>? content) {
  final topic = _stringValue(content?['required_subscription_topic'])
      .toLowerCase()
      .trim();
  switch (topic) {
    case 'education':
      return 'Education';
    case 'entertainment':
      return 'Entertainment';
    case 'infotainment':
      return 'Infotainment';
    case 'all':
      return 'All Access';
    default:
      return 'Subscription';
  }
}

String formatSubscriptionDate(String? isoValue) {
  if (isoValue == null || isoValue.trim().isEmpty) return '';
  try {
    final value = DateTime.parse(isoValue).toLocal();
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
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  } catch (_) {
    return isoValue;
  }
}

String contentAccessMessage(Map<String, dynamic>? content) {
  if (content == null) return 'Content access unavailable.';
  final reason = _stringValue(content['access_reason']).toLowerCase();
  final latest = latestSubscriptionFromContent(content);
  final requiredPlan = requiredPlanTopicLabel(content);

  switch (reason) {
    case 'subscription':
      final active = activeSubscriptionFromContent(content);
      final planName = _stringValue(active?['plan_name']);
      return planName.isEmpty
          ? 'Included in your active subscription.'
          : 'Included in your $planName plan.';
    case 'plan_mismatch':
      return 'This content requires a $requiredPlan plan or All Access.';
    case 'subscription_expired':
      final planName = _stringValue(latest?['plan_name']);
      final expiresAt = formatSubscriptionDate(
        _stringValue(latest?['expires_at']),
      );
      if (planName.isNotEmpty && expiresAt.isNotEmpty) {
        return 'Your $planName plan expired on $expiresAt. Renew to unlock this content.';
      }
      return 'Your subscription has expired. Renew to unlock this content.';
    case 'subscription_required':
    default:
      return 'Subscribe to the $requiredPlan plan to unlock this content.';
  }
}

String lockedActionLabel(Map<String, dynamic>? content) {
  final latest = latestSubscriptionFromContent(content);
  final status = _stringValue(latest?['status']).toLowerCase();
  if (status == 'expired') {
    return 'Renew Subscription';
  }
  return 'Get ${requiredPlanTopicLabel(content)} Plan';
}
