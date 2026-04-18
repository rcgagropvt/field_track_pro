import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import 'admin_shell.dart';

class AdminLoyaltyScreen extends StatefulWidget {
  const AdminLoyaltyScreen({super.key});
  @override
  State<AdminLoyaltyScreen> createState() => _AdminLoyaltyScreenState();
}

class _AdminLoyaltyScreenState extends State<AdminLoyaltyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;

  List<Map<String, dynamic>> _tiers = [];
  List<Map<String, dynamic>> _redemptions = [];
  List<Map<String, dynamic>> _rewards = [];

  final _fmt = NumberFormat('#,##,###');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.client
            .from('loyalty_tiers')
            .select('*, parties!inner(name, type, city, phone)')
            .order('total_points', ascending: false),
        SupabaseService.client
            .from('loyalty_redemptions')
            .select('*, parties!inner(name), loyalty_rewards!inner(name, reward_type)')
            .order('created_at', ascending: false),
        SupabaseService.client
            .from('loyalty_rewards')
            .select()
            .order('points_required'),
      ]);
      if (mounted) {
        setState(() {
          _tiers = List<Map<String, dynamic>>.from(results[0] as List);
          _redemptions = List<Map<String, dynamic>>.from(results[1] as List);
          _rewards = List<Map<String, dynamic>>.from(results[2] as List);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Loyalty load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _redemptions.where((r) => r['status'] == 'pending').length;
    final totalPoints = _tiers.fold<int>(0, (s, t) => s + ((t['total_points'] as int?) ?? 0));
    final totalParties = _tiers.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalty Management',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Parties (${_tiers.length})'),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Redemptions${pending > 0 ? '' : ''}'),
              if (pending > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text('$pending', style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ])),
            Tab(text: 'Rewards (${_rewards.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // KPI bar
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade50,
                child: Row(children: [
                  _kpi('Parties', '$totalParties', Colors.blue),
                  const SizedBox(width: 12),
                  _kpi('Total Points', _fmt.format(totalPoints), Colors.green),
                  const SizedBox(width: 12),
                  _kpi('Pending', '$pending', pending > 0 ? Colors.orange : Colors.grey),
                ]),
              ),
              Expanded(
                child: TabBarView(controller: _tabs, children: [
                  _tiersTab(),
                  _redemptionsTab(),
                  _rewardsTab(),
                ]),
              ),
            ]),
      floatingActionButton: _tabs.index == 2
          ? FloatingActionButton.extended(
              onPressed: _showAddRewardDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Reward', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB 1: ALL PARTY TIERS
  // ═══════════════════════════════════════
  Widget _tiersTab() {
    if (_tiers.isEmpty) {
      return const Center(child: Text('No loyalty data yet', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _tiers.length,
        itemBuilder: (_, i) {
          final t = _tiers[i];
          final party = t['parties'] as Map<String, dynamic>? ?? {};
          final tier = t['tier']?.toString() ?? 'bronze';
          final total = t['total_points'] as int? ?? 0;
          final redeemed = t['points_redeemed'] as int? ?? 0;
          final available = total - redeemed;
          final purchases = (t['total_purchases'] as num?)?.toDouble() ?? 0;

          final tierColor = tier == 'platinum'
              ? const Color(0xFF6C63FF)
              : tier == 'gold'
                  ? Colors.amber.shade700
                  : tier == 'silver'
                      ? Colors.blueGrey
                      : Colors.brown;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: tierColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(tier[0].toUpperCase(),
                        style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(party['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${party['type'] ?? ''} · ${party['city'] ?? ''}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tierColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(tier.toUpperCase(),
                            style: TextStyle(color: tierColor, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text('$available pts avail', style: const TextStyle(fontSize: 11, color: Colors.green)),
                      const SizedBox(width: 8),
                      Text('₹${_fmt.format(purchases)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                  ]),
                ),
                Column(children: [
                  Text('$total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('total pts', style: TextStyle(fontSize: 9, color: Colors.grey)),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB 2: REDEMPTIONS (APPROVE/REJECT)
  // ═══════════════════════════════════════
  Widget _redemptionsTab() {
    if (_redemptions.isEmpty) {
      return const Center(child: Text('No redemptions yet', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _redemptions.length,
        itemBuilder: (_, i) {
          final r = _redemptions[i];
          final party = r['parties'] as Map<String, dynamic>? ?? {};
          final reward = r['loyalty_rewards'] as Map<String, dynamic>? ?? {};
          final status = r['status']?.toString() ?? 'pending';
          final points = r['points_spent'] as int? ?? 0;
          final date = r['created_at'] != null
              ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(r['created_at'].toString()).toLocal())
              : '';

          final statusColor = status == 'fulfilled'
              ? Colors.green
              : status == 'approved'
                  ? Colors.blue
                  : status == 'rejected'
                      ? Colors.red
                      : Colors.orange;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.card_giftcard, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(party['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(reward['name']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Text('$points pts', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(width: 12),
                  Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const Spacer(),
                  if (status == 'pending') ...[
                    _actionBtn('Approve', Colors.green, () => _updateRedemption(r['id'], 'approved')),
                    const SizedBox(width: 8),
                    _actionBtn('Reject', Colors.red, () => _updateRedemption(r['id'], 'rejected')),
                  ],
                  if (status == 'approved')
                    _actionBtn('Mark Fulfilled', Colors.blue, () => _updateRedemption(r['id'], 'fulfilled')),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _updateRedemption(String id, String newStatus) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'approved_by': SupabaseService.userId,
      };
      if (newStatus == 'fulfilled') {
        updateData['fulfilled_at'] = DateTime.now().toIso8601String();
      }
      if (newStatus == 'approved') {
        updateData['approved_at'] = DateTime.now().toIso8601String();
      }
      if (newStatus == 'rejected') {
        // Refund points
        final redemption = _redemptions.firstWhere((r) => r['id'] == id);
        final partyId = redemption['party_id'];
        final pointsSpent = redemption['points_spent'] as int? ?? 0;

        await SupabaseService.client.from('loyalty_points').insert({
          'party_id': partyId,
          'points': pointsSpent,
          'action': 'adjustment',
          'description': 'Refund: Redemption rejected by admin',
        });

        await SupabaseService.client
            .from('loyalty_tiers')
            .update({
              'points_redeemed': ((_tiers.firstWhere(
                        (t) => t['party_id'] == partyId,
                        orElse: () => {'points_redeemed': 0},
                      )['points_redeemed'] as int? ?? 0) - pointsSpent)
                  .clamp(0, 999999),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('party_id', partyId);
      }

      await SupabaseService.client
          .from('loyalty_redemptions')
          .update(updateData)
          .eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Redemption ${newStatus == 'rejected' ? 'rejected & points refunded' : newStatus}'),
            backgroundColor: newStatus == 'rejected' ? Colors.red : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // ═══════════════════════════════════════
  // TAB 3: REWARDS CATALOG
  // ═══════════════════════════════════════
  Widget _rewardsTab() {
    if (_rewards.isEmpty) {
      return const Center(child: Text('No rewards configured', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _rewards.length,
        itemBuilder: (_, i) {
          final r = _rewards[i];
          final isActive = r['is_active'] == true;
          final stock = r['stock'] as int? ?? -1;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (isActive ? AppColors.primary : Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  r['reward_type'] == 'discount'
                      ? Icons.local_offer
                      : r['reward_type'] == 'cashback'
                          ? Icons.account_balance_wallet
                          : r['reward_type'] == 'gift'
                              ? Icons.card_giftcard
                              : Icons.local_shipping,
                  color: isActive ? AppColors.primary : Colors.grey,
                ),
              ),
              title: Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['description'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(children: [
                  Text('${r['points_required']} pts',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Text(stock == -1 ? 'Unlimited' : '$stock left',
                      style: TextStyle(fontSize: 11, color: stock == 0 ? Colors.red : Colors.grey)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isActive ? Colors.green : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                            color: isActive ? Colors.green : Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ]),
              trailing: PopupMenuButton<String>(
                onSelected: (v) => _handleRewardAction(r, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'toggle', child: Text('Toggle Active')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleRewardAction(Map<String, dynamic> reward, String action) async {
    try {
      if (action == 'toggle') {
        await SupabaseService.client
            .from('loyalty_rewards')
            .update({'is_active': !(reward['is_active'] == true)})
            .eq('id', reward['id']);
      } else if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Reward'),
            content: Text('Delete "${reward['name']}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await SupabaseService.client.from('loyalty_rewards').delete().eq('id', reward['id']);
      } else if (action == 'edit') {
        _showAddRewardDialog(existing: reward);
      }
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _showAddRewardDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?['description']?.toString() ?? '');
    final pointsCtrl = TextEditingController(text: existing?['points_required']?.toString() ?? '');
    final valueCtrl = TextEditingController(text: existing?['reward_value']?.toString() ?? '');
    String type = existing?['reward_type']?.toString() ?? 'discount';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Reward' : 'Add Reward'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 8),
              TextField(
                controller: pointsCtrl,
                decoration: const InputDecoration(labelText: 'Points Required'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueCtrl,
                decoration: const InputDecoration(labelText: 'Reward Value (₹)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: ['discount', 'cashback', 'gift', 'free_product'].map((t) {
                return ChoiceChip(
                  label: Text(t.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 10)),
                  selected: type == t,
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  onSelected: (_) => setDialogState(() => type = t),
                );
              }).toList()),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'points_required': int.tryParse(pointsCtrl.text) ?? 0,
                  'reward_value': double.tryParse(valueCtrl.text) ?? 0,
                  'reward_type': type,
                };
                if (existing != null) {
                  await SupabaseService.client.from('loyalty_rewards').update(data).eq('id', existing['id']);
                } else {
                  await SupabaseService.client.from('loyalty_rewards').insert(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAll();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(existing != null ? 'Update' : 'Add', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
