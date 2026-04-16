import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class AgingAnalysisScreen extends StatefulWidget {
  const AgingAnalysisScreen({super.key});
  @override
  State<AgingAnalysisScreen> createState() => _AgingAnalysisScreenState();
}

class _AgingAnalysisScreenState extends State<AgingAnalysisScreen> {
  bool _loading = true;
  Map<String, List<Map<String, dynamic>>> _buckets = {
    '0-30': [], '31-60': [], '61-90': [], '90+': [],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = SupabaseService.userId!;
    final today = DateTime.now();

    try {
      final invoices = await SupabaseService.client
          .from('invoices')
          .select()
          .eq('user_id', uid)
          .neq('status', 'paid')
          .order('due_date');

      final buckets = <String, List<Map<String, dynamic>>>{
        '0-30': [], '31-60': [], '61-90': [], '90+': [],
      };

      for (final inv in invoices as List) {
        final due = DateTime.tryParse(inv['due_date'] ?? '');
        if (due == null) continue;
        final days = today.difference(due).inDays;
        final entry = Map<String, dynamic>.from(inv);
        entry['days_overdue'] = days < 0 ? 0 : days;

        if (days <= 30) buckets['0-30']!.add(entry);
        else if (days <= 60) buckets['31-60']!.add(entry);
        else if (days <= 90) buckets['61-90']!.add(entry);
        else buckets['90+']!.add(entry);
      }

      if (mounted) setState(() { _buckets = buckets; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _bucketTotal(String key) => _buckets[key]!
      .fold(0, (s, i) => s + ((i['balance'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,###');
    final colors = {
      '0-30':  Colors.green,
      '31-60': Colors.orange,
      '61-90': Colors.deepOrange,
      '90+':   Colors.red.shade800,
    };
    final labels = {
      '0-30':  '0–30 Days',
      '31-60': '31–60 Days',
      '61-90': '61–90 Days',
      '90+':   '90+ Days',
    };

    final total = _buckets.values
        .expand((l) => l)
        .fold(0.0, (s, i) => s + ((i['balance'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Aging Analysis',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Total outstanding banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text('Total Outstanding',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('₹${fmt.format(total)}',
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Pie chart
                if (total > 0)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text('Aging Breakdown',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: PieChart(PieChartData(
                            sections: _buckets.entries.map((e) {
                              final v = _bucketTotal(e.key);
                              if (v == 0) return PieChartSectionData(value: 0, radius: 0);
                              return PieChartSectionData(
                                value: v,
                                color: colors[e.key],
                                title: '${(v / total * 100).toStringAsFixed(0)}%',
                                radius: 70,
                                titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              );
                            }).where((s) => s.value > 0).toList(),
                            sectionsSpace: 3,
                            centerSpaceRadius: 40,
                          )),
                        ),
                        const SizedBox(height: 12),
                        // Legend
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: _buckets.keys.map((k) {
                            return Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 12, height: 12,
                                  decoration: BoxDecoration(
                                    color: colors[k],
                                    borderRadius: BorderRadius.circular(3),
                                  )),
                              const SizedBox(width: 6),
                              Text(labels[k]!,
                                  style: const TextStyle(fontSize: 12)),
                            ]);
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Buckets
                ..._buckets.entries.map((e) {
                  final bTotal = _bucketTotal(e.key);
                  if (_buckets[e.key]!.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors[e.key]!.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: colors[e.key]!.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors[e.key],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(labels[e.key]!,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: colors[e.key],
                                  fontSize: 14)),
                          const Spacer(),
                          Text('${_buckets[e.key]!.length} invoices',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 12),
                          Text('₹${fmt.format(bTotal)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: colors[e.key])),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      ..._buckets[e.key]!.map((inv) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border(
                            left: BorderSide(
                                color: colors[e.key]!, width: 3),
                          ),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(inv['party_name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Text(inv['invoice_number'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${fmt.format((inv['balance'] as num?)?.toDouble() ?? 0)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: colors[e.key]),
                              ),
                              Text(
                                '${inv['days_overdue']} days overdue',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ]),
                      )),
                      const SizedBox(height: 12),
                    ],
                  );
                }),
              ],
            ),
    );
  }
}


