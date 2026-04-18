import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';

class TargetScreen extends StatefulWidget {
  const TargetScreen({super.key});
  @override
  State<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends State<TargetScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = SupabaseService.userId!;
      final res = await SupabaseService.client.rpc('calculate_incentive',
          params: {
            'p_user_id': uid,
            'p_month': _selectedMonth,
            'p_year': _selectedYear
          }) as List?;

      if (mounted) {
        setState(() {
          _data = (res != null && res.isNotEmpty) ? res.first : null;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Target load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('My Targets',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(children: [
        _monthPicker(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _data == null
                  ? _noTargetView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _incentiveCard(),
                          const SizedBox(height: 16),
                          _summaryCard(),
                          const SizedBox(height: 16),
                          _metricCard(
                            icon: Icons.store,
                            label: 'Visits',
                            achieved: _data!['out_achieved_visits'] ?? 0,
                            target: _data!['out_target_visits'] ?? 0,
                            color: Colors.blue,
                            format: (v) => v.toInt().toString(),
                          ),
                          _metricCard(
                            icon: Icons.shopping_cart,
                            label: 'Orders',
                            achieved: _data!['out_achieved_orders'] ?? 0,
                            target: _data!['out_target_orders'] ?? 0,
                            color: Colors.orange,
                            format: (v) => v.toInt().toString(),
                          ),
                          _metricCard(
                            icon: Icons.currency_rupee,
                            label: 'Revenue',
                            achieved: _data!['out_achieved_revenue'] ?? 0,
                            target: _data!['out_target_revenue'] ?? 0,
                            color: Colors.green,
                            format: (v) => '₹${_fmt(v)}',
                          ),
                          _metricCard(
                            icon: Icons.person_add,
                            label: 'New Parties',
                            achieved: _data!['out_achieved_parties'] ?? 0,
                            target: _data!['out_target_parties'] ?? 0,
                            color: Colors.purple,
                            format: (v) => v.toInt().toString(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _incentiveCard() {
    final baseIncentive =
        ((_data!['out_base_incentive'] as num?)?.toDouble() ?? 0);
    final earnedIncentive =
        ((_data!['out_earned_incentive'] as num?)?.toDouble() ?? 0);
    final pct =
        ((_data!['out_achievement_pct'] as num?)?.toDouble() ?? 0);
    final slabLabel = _data!['out_slab_label'] ?? '';
    final itype = _data!['out_incentive_type'] ?? 'fixed';

    if (baseIncentive <= 0 && itype == 'fixed') {
      return const SizedBox.shrink();
    }

    final isEarning = earnedIncentive > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEarning
              ? [Colors.amber.shade600, Colors.orange.shade700]
              : [Colors.grey.shade500, Colors.grey.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (isEarning)
            BoxShadow(
                color: Colors.amber.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isEarning ? Icons.emoji_events : Icons.lock_outline,
                color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              isEarning ? 'INCENTIVE EARNED' : 'INCENTIVE LOCKED',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '₹${_fmt(earnedIncentive)}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold),
        ),
        if (itype == 'fixed' && baseIncentive > 0) ...[
          const SizedBox(height: 4),
          Text(
            'of ₹${_fmt(baseIncentive)} possible',
            style: TextStyle(
                color: Colors.white.withOpacity(0.8), fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            slabLabel,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12),
          ),
        ),
        if (!isEarning && itype == 'fixed') ...[
          const SizedBox(height: 10),
          Text(
            'Reach 70% to start earning incentive',
            style: TextStyle(
                color: Colors.white.withOpacity(0.7), fontSize: 11),
          ),
        ],
        if (itype == 'fixed' && pct < 100 && pct >= 70) ...[
          const SizedBox(height: 10),
          _nextSlabHint(pct, baseIncentive),
        ],
      ]),
    );
  }

  Widget _nextSlabHint(double pct, double base) {
    String hint;
    if (pct < 80) {
      hint =
          'Reach 80% to earn ₹${_fmt(base * 0.75)} (+₹${_fmt(base * 0.75 - base * 0.5)})';
    } else if (pct < 90) {
      hint =
          'Reach 90% to earn ₹${_fmt(base * 0.9)} (+₹${_fmt(base * 0.9 - base * 0.75)})';
    } else {
      hint =
          'Reach 100% to earn full ₹${_fmt(base)} (+₹${_fmt(base - base * 0.9)})';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.arrow_upward, color: Colors.white, size: 14),
        const SizedBox(width: 4),
        Text(hint,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      ]),
    );
  }

  Widget _summaryCard() {
    final pct =
        ((_data!['out_achievement_pct'] as num?)?.toDouble() ?? 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.7)
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const Text('Overall Achievement',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Text('${pct.toStringAsFixed(0)}%',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation(
              pct >= 80
                  ? Colors.greenAccent
                  : pct >= 50
                      ? Colors.orange
                      : Colors.redAccent,
            ),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
        Text(_motivational(pct),
            style:
                const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  String _motivational(double pct) {
    if (pct >= 100) return '🎉 Target achieved! Excellent work!';
    if (pct >= 80) return '💪 Almost there! Keep pushing!';
    if (pct >= 50) return '📈 Good progress, stay focused!';
    return '🚀 Let\'s pick up the pace!';
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Widget _monthPicker() => Container(
        color: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Icon(Icons.calendar_month, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _selectedMonth,
            underline: const SizedBox(),
            items: List.generate(
                12,
                (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(_months[i + 1]),
                    )),
            onChanged: (v) {
              setState(() => _selectedMonth = v!);
              _load();
            },
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _selectedYear,
            underline: const SizedBox(),
            items: [2024, 2025, 2026, 2027]
                .map((y) => DropdownMenuItem(
                      value: y,
                      child: Text(y.toString()),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedYear = v!);
              _load();
            },
          ),
          const Spacer(),
          Text('${_months[_selectedMonth]} $_selectedYear',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      );

  Widget _noTargetView() => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.track_changes,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No target set for this month',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('Ask your admin to set a monthly target',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            ]),
      );

  Widget _metricCard({
    required IconData icon,
    required String label,
    required dynamic achieved,
    required dynamic target,
    required Color color,
    required String Function(double) format,
  }) {
    final a = (achieved as num).toDouble();
    final t = (target as num).toDouble();
    final pct = t > 0 ? (a / t * 100).clamp(0.0, 100.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Text('${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: pct >= 80
                          ? Colors.green
                          : pct >= 50
                              ? Colors.orange
                              : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(format(a),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20)),
                  Text('/ ${format(t)}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 14)),
                ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(
                  pct >= 80
                      ? Colors.green
                      : pct >= 50
                          ? Colors.orange
                          : Colors.red,
                ),
                minHeight: 8,
              ),
            ),
          ]),
    );
  }
}
