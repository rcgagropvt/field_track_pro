import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import 'set_targets_screen.dart';

class AdminTargetsScreen extends StatefulWidget {
  const AdminTargetsScreen({super.key});
  @override
  State<AdminTargetsScreen> createState() => _AdminTargetsScreenState();
}

class _AdminTargetsScreenState extends State<AdminTargetsScreen> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final from = '$_selectedYear-${_pad(_selectedMonth)}-01T00:00:00.000';
      final nextMonth = _selectedMonth == 12 ? 1 : _selectedMonth + 1;
      final nextYear = _selectedMonth == 12 ? _selectedYear + 1 : _selectedYear;
      final to = '$nextYear-${_pad(nextMonth)}-01T00:00:00.000';

      final employees = await SupabaseService.client
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'employee')
          .eq('is_active', true)
          .order('full_name');

      final targets = await SupabaseService.client
          .from('targets')
          .select()
          .eq('month', _selectedMonth)
          .eq('year', _selectedYear);

      final visits = await SupabaseService.client
          .from('visits').select('user_id')
          .gte('check_in_time', from).lt('check_in_time', to);

      final orders = await SupabaseService.client
          .from('orders').select('user_id, total_amount')
          .gte('created_at', from).lt('created_at', to);

      final results = <Map<String, dynamic>>[];
      for (final emp in employees as List) {
        final uid = emp['id'] as String;
        final target = (targets as List).cast<Map<String, dynamic>>()
            .where((t) => t['user_id'] == uid).firstOrNull;
        final empVisits = (visits as List).where((v) => v['user_id'] == uid).length;
        final empOrders = (orders as List).where((o) => o['user_id'] == uid).toList();
        final revenue = empOrders.fold<double>(0, (s, o) =>
            s + ((o['total_amount'] as num?)?.toDouble() ?? 0));

        double pct = 0;
        if (target != null) {
          int count = 0;
          double total = 0;
          void add(String key, double achieved) {
            final t = (target[key] as num?)?.toDouble() ?? 0;
            if (t > 0) { total += (achieved / t * 100).clamp(0, 100); count++; }
          }
          add('target_visits', empVisits.toDouble());
          add('target_orders', empOrders.length.toDouble());
          add('target_revenue', revenue);
          if (count > 0) pct = total / count;
        }

        results.add({
          'id': uid,
          'name': emp['full_name'],
          'target': target,
          'visits': empVisits,
          'orders': empOrders.length,
          'revenue': revenue,
          'pct': pct,
        });
      }

      results.sort((a, b) => (b['pct'] as double).compareTo(a['pct'] as double));
      if (mounted) setState(() { _data = results; _loading = false; });
    } catch (e) {
      debugPrint('AdminTargets error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D2E),
      appBar: AppBar(
        title: const Text('Targets & Achievement',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1A1D2E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SetTargetsScreen()))
                .then((_) => _load()),
          ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
        ],
      ),
      body: Column(children: [
        _monthPicker(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _data.isEmpty
                  ? const Center(child: Text('No employees', style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _data.length,
                        itemBuilder: (_, i) => _empCard(_data[i], i),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _monthPicker() => Container(
        color: const Color(0xFF252840),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _selectedMonth,
            dropdownColor: const Color(0xFF252840),
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            items: List.generate(12, (i) => DropdownMenuItem(
              value: i + 1,
              child: Text(_months[i + 1], style: const TextStyle(color: Colors.white)),
            )),
            onChanged: (v) { setState(() => _selectedMonth = v!); _load(); },
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _selectedYear,
            dropdownColor: const Color(0xFF252840),
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(
              value: y, child: Text(y.toString(), style: const TextStyle(color: Colors.white)),
            )).toList(),
            onChanged: (v) { setState(() => _selectedYear = v!); _load(); },
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16, color: Colors.blue),
            label: const Text('Set Target', style: TextStyle(color: Colors.blue, fontSize: 12)),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SetTargetsScreen()))
                .then((_) => _load()),
          ),
        ]),
      );

  Widget _empCard(Map<String, dynamic> d, int rank) {
    final pct = d['pct'] as double;
    final hasTarget = d['target'] != null;
    final color = pct >= 80 ? Colors.greenAccent : pct >= 50 ? Colors.orange : Colors.redAccent;
    final rankColors = [Colors.amber, Colors.grey.shade400, Colors.brown.shade300];

    final visitsAchieved = d['visits'] as int;
    final ordersAchieved = d['orders'] as int;
    final revenueAchieved = d['revenue'] as double;
    final targetData = d['target'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252840),
        borderRadius: BorderRadius.circular(14),
        border: rank < 3 && hasTarget
            ? Border.all(color: rankColors[rank].withOpacity(0.4), width: 1)
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (rank < 3 && hasTarget)
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: rankColors[rank].withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text('#${rank + 1}',
                  style: TextStyle(color: rankColors[rank], fontWeight: FontWeight.bold, fontSize: 12))),
            ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withOpacity(0.3),
            child: Text((d['name'] as String)[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['name'] as String,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              if (!hasTarget)
                const Text('No target set', style: TextStyle(color: Colors.grey, fontSize: 11))
              else
                Text('${pct.toStringAsFixed(0)}% achieved',
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (hasTarget)
            Text('${pct.toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
        ]),
        if (hasTarget && targetData != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _stat(Icons.store,
                '$visitsAchieved / ${targetData["target_visits"] ?? 0}',
                Colors.blue),
            _stat(Icons.shopping_cart,
                '$ordersAchieved / ${targetData["target_orders"] ?? 0}',
                Colors.orange),
            _stat(Icons.currency_rupee, _fmt(revenueAchieved), Colors.green),
          ]),
        ],
      ]),
    );
  }

  Widget _stat(IconData icon, String val, Color color) => Expanded(
        child: Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(val, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      );

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
}


