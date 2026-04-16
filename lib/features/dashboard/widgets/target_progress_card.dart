import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../targets/screens/target_screen.dart';

class TargetProgressCard extends StatefulWidget {
  const TargetProgressCard({super.key});
  @override
  State<TargetProgressCard> createState() => _TargetProgressCardState();
}

class _TargetProgressCardState extends State<TargetProgressCard> {
  bool _loading = true;
  bool _hasTarget = false;
  String _month = '';
  Map<String, double> _pcts = {};
  double _overall = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _load() async {
    final now = DateTime.now();
    final uid = SupabaseService.userId!;
    final months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    _month = '${months[now.month]} ${now.year}';

    try {
      final targets = await SupabaseService.client
          .from('targets')
          .select()
          .eq('user_id', uid)
          .eq('month', now.month)
          .eq('year', now.year)
          .limit(1);

      if ((targets as List).isEmpty) {
        if (mounted) setState(() { _hasTarget = false; _loading = false; });
        return;
      }

      final target = targets.first;
      final from = '${now.year}-${_pad(now.month)}-01T00:00:00.000';
      final nm = now.month == 12 ? 1 : now.month + 1;
      final ny = now.month == 12 ? now.year + 1 : now.year;
      final to = '$ny-${_pad(nm)}-01T00:00:00.000';

      final visits = await SupabaseService.client
          .from('visits').select('id').eq('user_id', uid)
          .gte('check_in_time', from).lt('check_in_time', to);
      final orders = await SupabaseService.client
          .from('orders').select('id, total_amount').eq('user_id', uid)
          .gte('created_at', from).lt('created_at', to);
      final parties = await SupabaseService.client
          .from('parties').select('id').eq('user_id', uid)
          .gte('created_at', from).lt('created_at', to);

      double revenue = 0;
      for (final o in orders as List) {
        revenue += (o['total_amount'] as num?)?.toDouble() ?? 0;
      }

      double pct(dynamic achieved, String key) {
        final t = (target[key] as num?)?.toDouble() ?? 0;
        if (t == 0) return -1;
        return ((achieved as num).toDouble() / t * 100).clamp(0, 100);
      }

      final map = <String, double>{};
      final vPct = pct((visits as List).length, 'target_visits');
      final oPct = pct((orders as List).length, 'target_orders');
      final rPct = pct(revenue, 'target_revenue');
      final pPct = pct((parties as List).length, 'target_parties');

      if (vPct >= 0) map['Visits'] = vPct;
      if (oPct >= 0) map['Orders'] = oPct;
      if (rPct >= 0) map['Revenue'] = rPct;
      if (pPct >= 0) map['New Parties'] = pPct;

      final active = map.values.toList();
      final overall = active.isEmpty ? 0.0
          : active.fold(0.0, (s, v) => s + v) / active.length;

      if (mounted) setState(() {
        _hasTarget = true; _pcts = map; _overall = overall; _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _hasTarget = false; _loading = false; });
    }
  }

  Color _color(double pct) {
    if (pct >= 80) return Colors.greenAccent.shade400;
    if (pct >= 50) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: SizedBox(height: 40, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (!_hasTarget) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.track_changes, color: Colors.grey.shade400, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('No Target Set', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            SizedBox(height: 2),
            Text('Ask your admin to set a target for this month',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
        ]),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const TargetScreen())),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.75)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.track_changes, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('$_month Target', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const Spacer(),
            Text('${_overall.toStringAsFixed(0)}% overall',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _overall / 100,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(_color(_overall)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: _pcts.entries.map((e) => Expanded(
              child: Column(children: [
                Text('${e.value.toStringAsFixed(0)}%', style: TextStyle(
                    color: _color(e.value), fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(e.key, style: const TextStyle(color: Colors.white60, fontSize: 10),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: e.value / 100,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(_color(e.value)),
                    minHeight: 4,
                  ),
                ),
              ]),
            )).toList(),
          ),
        ]),
      ),
    );
  }
}

