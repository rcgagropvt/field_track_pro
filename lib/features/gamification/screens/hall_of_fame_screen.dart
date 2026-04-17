import 'package:flutter/material.dart';
import 'package:vartmaan_pulse/core/services/supabase_service.dart';
import 'package:intl/intl.dart';

class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({super.key});
  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.client.rpc('get_hall_of_fame', params: {'p_limit': 30}) as List? ?? [];
      if (mounted) setState(() {
        _entries = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Hall of fame error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hall of Fame', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8F4FF),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_outlined, size: 64, color: Colors.amber.shade200),
                      const SizedBox(height: 12),
                      const Text('No champions yet!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Weekly winners will appear here', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) {
                      final e = _entries[i];
                      final rank = e['out_rank'] as int? ?? 1;
                      final periodStart = DateTime.tryParse(e['out_period_start']?.toString() ?? '');
                      final periodEnd = DateTime.tryParse(e['out_period_end']?.toString() ?? '');
                      final periodStr = periodStart != null && periodEnd != null
                          ? '${DateFormat('dd MMM').format(periodStart)} - ${DateFormat('dd MMM yyyy').format(periodEnd)}'
                          : '';
                      final isChampion = rank == 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: isChampion
                              ? LinearGradient(colors: [Colors.amber.shade50, Colors.amber.shade100])
                              : null,
                          color: isChampion ? null : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isChampion ? Colors.amber.shade300 : Colors.grey.shade200,
                            width: isChampion ? 2 : 1,
                          ),
                          boxShadow: [
                            if (isChampion)
                              BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isChampion) ...[
                                  const Text('👑', style: TextStyle(fontSize: 28)),
                                  const SizedBox(width: 8),
                                ] else ...[
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.grey.shade200,
                                    child: Text('#$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e['out_full_name'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isChampion ? 18 : 15,
                                          color: isChampion ? Colors.amber.shade900 : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        '${e['out_period_type'] == 'weekly' ? 'Weekly' : 'Monthly'} Champion  •  $periodStr',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isChampion)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade700,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('CHAMPION', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _stat('Visits', '${e['out_visits'] ?? 0}', Icons.place, Colors.blue),
                                _stat('Orders', '${e['out_orders'] ?? 0}', Icons.shopping_cart, Colors.green),
                                _stat('Revenue', '₹${NumberFormat.compact().format(e['out_revenue'] ?? 0)}', Icons.currency_rupee, Colors.orange),
                                _stat('XP', '${e['out_xp'] ?? 0}', Icons.bolt, Colors.purple),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }
}
