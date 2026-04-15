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
  Map<String, dynamic>? _target;
  Map<String, dynamic> _achieved = {};
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = SupabaseService.userId!;

      final targets = await SupabaseService.client
          .from('targets')
          .select()
          .eq('user_id', uid)
          .eq('month', _selectedMonth)
          .eq('year', _selectedYear)
          .limit(1);

      _target = (targets as List).isNotEmpty ? targets.first : null;

      final from = '$_selectedYear-${_pad(_selectedMonth)}-01T00:00:00.000';
      final nextMonth = _selectedMonth == 12 ? 1 : _selectedMonth + 1;
      final nextYear = _selectedMonth == 12 ? _selectedYear + 1 : _selectedYear;
      final to = '$nextYear-${_pad(nextMonth)}-01T00:00:00.000';

      final visits = await SupabaseService.client
          .from('visits')
          .select('id')
          .eq('user_id', uid)
          .gte('check_in_time', from)
          .lt('check_in_time', to);

      final orders = await SupabaseService.client
          .from('orders')
          .select('id, total_amount')
          .eq('user_id', uid)
          .gte('created_at', from)
          .lt('created_at', to);

      final parties = await SupabaseService.client
          .from('parties')
          .select('id')
          .eq('user_id', uid)
          .gte('created_at', from)
          .lt('created_at', to);

      double revenue = 0;
      for (final o in orders as List) {
        revenue += (o['total_amount'] as num?)?.toDouble() ?? 0;
      }

      if (mounted) {
        setState(() {
          _achieved = {
            'visits': (visits as List).length,
            'orders': (orders as List).length,
            'revenue': revenue,
            'parties': (parties as List).length,
          };
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Target load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  double _pct(String key, String targetKey) {
    final t = (_target?[targetKey] as num?)?.toDouble() ?? 0;
    final a = (_achieved[key] as num?)?.toDouble() ?? 0;
    if (t == 0) return 0;
    return (a / t * 100).clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('My Targets', style: TextStyle(fontWeight: FontWeight.bold)),
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
              : _target == null
                  ? _noTargetView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _summaryCard(),
                          const SizedBox(height: 16),
                          _metricCard(
                            icon: Icons.store,
                            label: 'Visits',
                            achieved: _achieved['visits'] ?? 0,
                            target: _target!['target_visits'] ?? 0,
                            color: Colors.blue,
                            format: (v) => v.toInt().toString(),
                          ),
                          _metricCard(
                            icon: Icons.shopping_cart,
                            label: 'Orders',
                            achieved: _achieved['orders'] ?? 0,
                            target: _target!['target_orders'] ?? 0,
                            color: Colors.orange,
                            format: (v) => v.toInt().toString(),
                          ),
                          _metricCard(
                            icon: Icons.currency_rupee,
                            label: 'Revenue',
                            achieved: _achieved['revenue'] ?? 0,
                            target: _target!['target_revenue'] ?? 0,
                            color: Colors.green,
                            format: (v) => '₹${_fmt(v)}',
                          ),
                          _metricCard(
                            icon: Icons.person_add,
                            label: 'New Parties',
                            achieved: _achieved['parties'] ?? 0,
                            target: _target!['target_parties'] ?? 0,
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

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Widget _monthPicker() => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Icon(Icons.calendar_month, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _selectedMonth,
            underline: const SizedBox(),
            items: List.generate(12, (i) => DropdownMenuItem(
              value: i + 1,
              child: Text(_months[i + 1]),
            )),
            onChanged: (v) { setState(() => _selectedMonth = v!); _load(); },
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _selectedYear,
            underline: const SizedBox(),
            items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(
              value: y, child: Text(y.toString()),
            )).toList(),
            onChanged: (v) { setState(() => _selectedYear = v!); _load(); },
          ),
          const Spacer(),
          Text('${_months[_selectedMonth]} $_selectedYear',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      );

  Widget _noTargetView() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.track_changes, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No target set for this month',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Ask your admin to set a monthly target',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
      );

  Widget _summaryCard() {
    final metrics = ['visits', 'orders', 'revenue', 'parties'];
    final keys = ['target_visits', 'target_orders', 'target_revenue', 'target_parties'];
    double totalPct = 0;
    int count = 0;
    for (int i = 0; i < metrics.length; i++) {
      final t = (_target![keys[i]] as num?)?.toDouble() ?? 0;
      if (t > 0) {
        totalPct += _pct(metrics[i], keys[i]);
        count++;
      }
    }
    final avgPct = count > 0 ? totalPct / count : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const Text('Overall Achievement', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Text('${avgPct.toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: avgPct / 100,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation(
              avgPct >= 80 ? Colors.greenAccent : avgPct >= 50 ? Colors.orange : Colors.redAccent,
            ),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
        Text(_motivational(avgPct.toDouble()),
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  String _motivational(double pct) {
    if (pct >= 100) return '🎉 Target achieved! Excellent work!';
    if (pct >= 80) return '💪 Almost there! Keep pushing!';
    if (pct >= 50) return '📈 Good progress, stay focused!';
    return '🚀 Let\'s pick up the pace!';
  }

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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          Text('${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                  color: pct >= 80 ? Colors.green : pct >= 50 ? Colors.orange : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(format(a), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          Text('/ ${format(t)}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(
              pct >= 80 ? Colors.green : pct >= 50 ? Colors.orange : Colors.red,
            ),
            minHeight: 8,
          ),
        ),
      ]),
    );
  }
}
