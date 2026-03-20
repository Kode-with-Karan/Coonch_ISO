import 'package:meta/meta.dart';
import 'api_service.dart';

@immutable
class RewardCoupon {
  final String code;
  final String title;
  final String description;
  final int cost;
  final Map<String, dynamic> payload;

  const RewardCoupon({
    required this.code,
    required this.title,
    required this.description,
    required this.cost,
    required this.payload,
  });

  factory RewardCoupon.fromJson(Map<String, dynamic> json) {
    return RewardCoupon(
      code: json['code'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      cost: (json['cost'] as num).toInt(),
      payload: (json['payload'] as Map<String, dynamic>? ?? {}),
    );
  }
}

@immutable
class RewardSummary {
  final int points;
  final int level;
  final int nextThreshold;
  final List<RewardCoupon> coupons;
  final Set<String> redeemed;
  final List<Map<String, dynamic>> transactions;
  final int? lastTransactionDelta;

  const RewardSummary({
    required this.points,
    required this.level,
    required this.nextThreshold,
    required this.coupons,
    required this.redeemed,
    required this.transactions,
    this.lastTransactionDelta,
  });

  factory RewardSummary.fromJson(Map<String, dynamic> json) {
    final couponList = (json['coupons'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(RewardCoupon.fromJson)
        .toList();
    final redeemed = Set<String>.from(json['redeemed'] ?? const []);
    final tx = (json['transactions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final lastTx = json['last_transaction'];
    int? lastDelta;
    if (lastTx is Map<String, dynamic> && lastTx['delta'] != null) {
      lastDelta = (lastTx['delta'] as num).toInt();
    }
    return RewardSummary(
      points: (json['points'] as num? ?? 0).toInt(),
      level: (json['level'] as num? ?? 1).toInt(),
      nextThreshold: (json['next_threshold'] as num? ?? 0).toInt(),
      coupons: couponList,
      redeemed: redeemed,
      transactions: tx,
      lastTransactionDelta: lastDelta,
    );
  }
}

class RewardService {
  final ApiService api;
  RewardService(this.api);

  Future<RewardSummary> fetchSummary() async {
    final res = await api.getJson('api/v1/rewards/summary/');
    return RewardSummary.fromJson(res);
  }

  Future<RewardSummary> redeem(String code) async {
    final res = await api.postJson('api/v1/rewards/redeem/$code/', {});
    return RewardSummary.fromJson(res);
  }

  Future<RewardSummary> sendEvent({
    required String event,
    String? contentId,
    int? amount,
    String? note,
  }) async {
    final payload = <String, dynamic>{'event': event};
    if (contentId != null) payload['content_id'] = contentId;
    if (amount != null) payload['amount'] = amount;
    if (note != null && note.isNotEmpty) payload['note'] = note;
    final res = await api.postJson('api/v1/rewards/event/', payload);
    return RewardSummary.fromJson(res);
  }
}
