import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/widgets.dart';
import '../../theme.dart';
import '../../services/reward_service.dart';
import '../../services/api_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  int _selectedBadge = 0;
  int _points = 0;
  int _level = 1;
  int _nextThresholdValue = 0;
  bool _loading = true;
  Set<String> _redeemed = {};
  List<RewardCoupon> _coupons = const [];

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final summary = await RewardService(api).fetchSummary();
      if (!mounted) return;
      setState(() {
        _points = summary.points;
        _level = summary.level;
        _nextThresholdValue = summary.nextThreshold;
        _redeemed = summary.redeemed;
        _coupons = summary.coupons;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load rewards: $e')));
    }
  }

  Widget _card({required Widget child}) {
    return CardContainer(padding: const EdgeInsets.all(14), child: child);
  }

  Widget _badgeItem(int level) {
    final selected = level == _level;
    final earned = level <= _level;
    
    final badgeColors = [
      const Color(0xFFCD7F32), // Bronze
      const Color(0xFFC0C0C0), // Silver
      Colors.blue,
      Colors.purple,
      Colors.orange,
    ];
    
    final badgeIcons = [
      Icons.star_border,
      Icons.star_half,
      Icons.star,
      Icons.workspace_premium,
      Icons.diamond,
    ];
    
    final color = earned 
        ? (level <= 5 ? badgeColors[level - 1] : Colors.orange) 
        : Colors.grey;
    final icon = level <= 5 ? badgeIcons[level - 1] : Icons.diamond;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedBadge = level),
      child: Container(
        width: 92,
        height: 92,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(31) : (earned ? Colors.white : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : (earned ? color.withAlpha(77) : Colors.grey.shade300),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withAlpha(51), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(
              radius: 22,
              backgroundColor: earned ? color : Colors.grey.shade300,
              child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(height: 8),
          Text(
            earned ? 'Level $level' : 'Locked',
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: earned ? Colors.black87 : Colors.grey,
            ),
          ),
        ]),
      ),
    );
  }

  int _levelForPoints(int pts) {
    return _level; // level is already computed by backend
  }

  int _nextThreshold(int pts) {
    if (_nextThresholdValue <= 0) return pts;
    return _nextThresholdValue;
  }

  Widget _couponCard(RewardCoupon coupon) {
    final redeemed = _redeemed.contains(coupon.code);
    final enough = _points >= coupon.cost;
    String label;
    if (redeemed) {
      label = 'Redeemed';
    } else if (enough) {
      label = 'Redeem';
    } else {
      label = '${coupon.cost - _points} pts needed';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.avatarBackground,
          borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(coupon.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(coupon.description,
            style: const TextStyle(color: Colors.black54, height: 1.3)),
        const SizedBox(height: 10),
        Text('Requires ${coupon.cost} pts',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: (!enough || redeemed || _loading)
                ? null
                : () async {
                    try {
                      final api =
                          Provider.of<ApiService>(context, listen: false);
                      final summary =
                          await RewardService(api).redeem(coupon.code);
                      await _loadRewards();
                      if (!mounted) return;
                      final delta = summary.lastTransactionDelta;
                      final msg = delta != null && delta < 0
                          ? '${coupon.title} unlocked (spent ${delta.abs()} pts)'
                          : '${coupon.title} unlocked';
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(msg)));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Unable to redeem: $e')));
                    }
                  },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: Text(label),
          ),
        )
      ]),
    );
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
        title: const Text('Rewards', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          _card(
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Points Earned',
                          style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(_loading ? '…' : '$_points pts',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.lightBlue[50],
                    borderRadius: BorderRadius.circular(12)),
                child: Text('Level ${_levelForPoints(_points)}',
                    style: const TextStyle(color: Colors.lightBlue)),
              )
            ]),
          ),
          _card(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Progress Bar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                    value: _loading
                        ? 0
                        : (_points / _nextThreshold(_points)).clamp(0, 1),
                    minHeight: 16,
                    backgroundColor: Colors.lightBlue[50],
                    color: Colors.lightBlue),
              ),
              const SizedBox(height: 6),
              if (!_loading)
                Text(
                    _points >= _nextThreshold(_points)
                        ? 'Max level reached'
                        : '${_nextThreshold(_points) - _points} pts to next level',
                    style: const TextStyle(color: Colors.black54)),
            ]),
          ),
          _card(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Badges',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  const SizedBox(width: 6),
                  _badgeItem(1),
                  _badgeItem(2),
                  _badgeItem(3),
                  _badgeItem(4),
                  _badgeItem(5),
                ]),
              ),
            ]),
          ),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.0),
              child: SizedBox(height: 8)),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.0),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Available Coupon',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(18.0),
                child: CircularProgressIndicator())
          else
            ..._coupons.map(_couponCard),
          const SizedBox(height: 60),
        ]),
      ),
    );
  }
}
