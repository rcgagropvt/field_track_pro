import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../visits/screens/start_visit_screen.dart';
import 'party_action_sheet.dart';

class SmartPlannerScreen extends StatefulWidget {
  const SmartPlannerScreen({super.key});
  @override
  State<SmartPlannerScreen> createState() => _SmartPlannerScreenState();
}

class _SmartPlannerScreenState extends State<SmartPlannerScreen> {
  List<Map<String, dynamic>> _priorities = [];
  bool _loading = true;
  String _filter = 'all'; // all, urgent, recommended, normal

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = SupabaseService.userId;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final data = await SupabaseService.client
          .rpc('ai_smart_visit_priority', params: {'p_user_id': uid}) as List;
      if (mounted) {
        setState(() {
          _priorities = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Smart planner error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _priorities;
    return _priorities.where((p) => p['out_priority_label'] == _filter).toList();
  }

  int get _urgentCount =>
      _priorities.where((p) => p['out_priority_label'] == 'urgent').length;
  int get _recommendedCount =>
      _priorities.where((p) => p['out_priority_label'] == 'recommended').length;
  int get _normalCount =>
      _priorities.where((p) => p['out_priority_label'] == 'normal').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Smart Planner',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('AI-ranked visit priorities for today',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _priorities.isEmpty
              ? _emptyState()
              : Column(children: [
                  // KPI row
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(children: [
                      _kpi('Urgent', _urgentCount, Colors.red),
                      const SizedBox(width: 10),
                      _kpi('Recommended', _recommendedCount, Colors.orange),
                      const SizedBox(width: 10),
                      _kpi('Normal', _normalCount, Colors.green),
                    ]),
                  ),
                  // Filter chips
                  Container(
                    color: Colors.white,
                    height: 46,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      children: [
                        _chip('all', 'All (${_priorities.length})'),
                        _chip('urgent', 'Urgent ($_urgentCount)'),
                        _chip('recommended', 'Recommended ($_recommendedCount)'),
                        _chip('normal', 'Normal ($_normalCount)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Party list
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _partyCard(_filtered[i], i),
                      ),
                    ),
                  ),
                ]),
    );
  }

  Widget _kpi(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text('$count',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        ]),
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.primary,
            )),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        backgroundColor: AppColors.primarySurface,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        side: BorderSide.none,
      ),
    );
  }

  Widget _partyCard(Map<String, dynamic> p, int index) {
    final label = p['out_priority_label']?.toString() ?? 'normal';
    final score = (p['out_priority_score'] as num?)?.toInt() ?? 0;
    final days = p['out_days_since_visit'] as int? ?? 999;
    final outstanding = (p['out_outstanding_balance'] as num?)?.toDouble() ?? 0;
    final stockAlert = p['out_stock_alert'] == true;
    final reasons = (p['out_reasons'] as List?)?.cast<String>() ?? [];
    final rank = p['out_priority_rank'] as int? ?? (index + 1);

    final color = label == 'urgent'
        ? Colors.red
        : label == 'recommended'
            ? Colors.orange
            : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // Header with rank
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: Row(children: [
            // Rank badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('#$rank',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['out_party_name']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Row(children: [
                  if (p['out_party_type'] != null)
                    Text(p['out_party_type'].toString().toUpperCase(),
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  if (p['out_city'] != null) ...[
                    Text(' · ', style: TextStyle(color: Colors.grey.shade400)),
                    Text(p['out_city'].toString(),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ]),
              ]),
            ),
            // Priority badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.psychology, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label.toUpperCase(),
                    style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
        ),

        // Reasons
        if (reasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: reasons.map((r) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_reasonIcon(r), size: 12, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Text(r, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                  ]),
                );
              }).toList(),
            ),
          ),

        // Metrics row
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(children: [
            _metric(Icons.calendar_today, days >= 999 ? 'Never visited' : '$days days ago',
                days > 14 ? Colors.red : days > 7 ? Colors.orange : Colors.grey),
            if (outstanding > 0) ...[
              const SizedBox(width: 12),
              _metric(Icons.account_balance_wallet, 'Rs.${outstanding.toStringAsFixed(0)}', Colors.orange),
            ],
            if (stockAlert) ...[
              const SizedBox(width: 12),
              _metric(Icons.inventory, 'Stock-out', Colors.red),
            ],
            const Spacer(),
            Text('Score: $score',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          ]),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Fetch full party data for action sheet
                  try {
                    final party = await SupabaseService.client
                        .from('parties')
                        .select()
                        .eq('id', p['out_party_id'])
                        .single();
                    if (mounted) {
                      showPartyActionSheet(context,
                          party: party, isAdmin: false, onActionCompleted: _load);
                    }
                  } catch (_) {}
                },
                icon: const Icon(Icons.info_outline, size: 14),
                label: const Text('Details', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final party = await SupabaseService.client
                        .from('parties')
                        .select()
                        .eq('id', p['out_party_id'])
                        .single();
                    if (mounted) {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => StartVisitScreen(party: party)));
                    }
                  } catch (_) {}
                },
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Start Visit', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    ).animate(delay: Duration(milliseconds: index * 60)).fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }

  Widget _metric(IconData icon, String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    ]);
  }

  IconData _reasonIcon(String reason) {
    if (reason.contains('Overdue') || reason.contains('Never') || reason.contains('Due'))
      return Icons.calendar_today;
    if (reason.contains('Outstanding')) return Icons.account_balance_wallet;
    if (reason.contains('High-value')) return Icons.star;
    if (reason.contains('Stock')) return Icons.inventory;
    return Icons.info_outline;
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.psychology, size: 60, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('No parties to prioritize',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
        const Text('Add parties and visit data to see AI recommendations',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }
}
