import 'package:flutter/material.dart';
import 'package:vartmaan_pulse/core/services/supabase_service.dart';
import '../widgets/milestone_celebration.dart';
import '../widgets/leaderboard_share.dart';
import 'hall_of_fame_screen.dart';
import 'notifications_screen.dart';

class GamificationScreen extends StatefulWidget {
  const GamificationScreen({super.key});
  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _myMilestones = [];
  Map<String, dynamic>? _myStats;
  int _unreadCount = 0;
  bool _loading = true;
  String _period = 'weekly';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait(
        [_loadLeaderboard(), _loadMilestones(), _loadUnreadCount()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadLeaderboard() async {
    try {
      final res = await SupabaseService.client.rpc('gamification_leaderboard',
              params: {'p_period': _period}) as List? ??
          [];
      final list = List<Map<String, dynamic>>.from(res);
      final uid = SupabaseService.userId;
      if (mounted)
        setState(() {
          _leaderboard = list;
          _myStats =
              list.firstWhere((e) => e['out_user_id'] == uid, orElse: () => {});
        });
    } catch (e) {
      debugPrint('Leaderboard error: $e');
    }
  }

  Future<void> _loadMilestones() async {
    try {
      final uid = SupabaseService.userId;
      if (uid == null) return;
      final res = await SupabaseService.client
              .rpc('check_milestones', params: {'p_user_id': uid}) as List? ??
          [];
      final milestones = List<Map<String, dynamic>>.from(res);
      if (mounted) {
        setState(() => _myMilestones = milestones);
        // Show celebration for uncelebrated milestones
        final uncelebrated =
            milestones.where((m) => m['out_is_new'] == true).toList();
        if (uncelebrated.isNotEmpty) {
          _showNextCelebration(uncelebrated, 0);
        }
      }
    } catch (e) {
      debugPrint('Milestones error: $e');
    }
  }

  void _showNextCelebration(List<Map<String, dynamic>> list, int index) {
    if (index >= list.length || !mounted) return;
    final m = list[index];
    MilestoneCelebration.show(
      context,
      title: m['out_title'] ?? 'Milestone!',
      description: 'Keep up the great work!',
      icon: m['out_icon'] ?? '🏆',
    ).then((_) {
      // Mark as celebrated
      SupabaseService.client
          .from('milestones')
          .update({'celebrated': true}).match({
        'user_id': SupabaseService.userId!,
        'milestone_type': m['out_milestone_type'],
        'milestone_value': m['out_milestone_value'],
      }).then((_) {});
      // Show next
      _showNextCelebration(list, index + 1);
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final res = await SupabaseService.client
          .from('notifications')
          .select('id')
          .eq('user_id', SupabaseService.userId!)
          .eq('is_read', false);
      if (mounted) setState(() => _unreadCount = (res as List).length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Leaderboard & XP',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // Notification bell with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen())),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Text('$_unreadCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Hall of Fame',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HallOfFameScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share to WhatsApp',
            onPressed: () => LeaderboardShare.shareToWhatsApp(
                leaderboard: _leaderboard, period: _period),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'My Stats'),
            Tab(text: 'Leaderboard'),
            Tab(text: 'Milestones'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _myStatsTab(),
                _leaderboardTab(),
                _milestonesTab(),
              ],
            ),
    );
  }

  Widget _myStatsTab() {
    if (_myStats == null || _myStats!.isEmpty) {
      return const Center(
          child: Text('Complete your first visit to see stats!',
              style: TextStyle(color: Colors.grey)));
    }
    final s = _myStats!;
    final xp = s['out_total_xp'] ?? 0;
    final level = s['out_level'] ?? 'Rookie';
    final nextLevelXp = xp < 500
        ? 500
        : xp < 2000
            ? 2000
            : xp < 5000
                ? 5000
                : 10000;
    final progress = (xp / nextLevelXp).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Level card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: level == 'Sales Legend'
                    ? [Colors.amber.shade600, Colors.amber.shade900]
                    : level == 'Territory Champion'
                        ? [Colors.purple.shade400, Colors.purple.shade700]
                        : level == 'Field Star'
                            ? [Colors.blue.shade400, Colors.blue.shade700]
                            : [Colors.grey.shade400, Colors.grey.shade600],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  level == 'Sales Legend'
                      ? '👑'
                      : level == 'Territory Champion'
                          ? '🏅'
                          : level == 'Field Star'
                              ? '⭐'
                              : '🌱',
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Text(level.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Rank #${s['out_rank'] ?? '-'}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 14)),
                const SizedBox(height: 16),
                // XP progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress.toDouble(),
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text('$xp / $nextLevelXp XP',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Stats grid
          Row(
            children: [
              _statCard('Visits', '${s['out_visits'] ?? 0}', Icons.place,
                  Colors.blue),
              const SizedBox(width: 10),
              _statCard('Orders', '${s['out_orders'] ?? 0}',
                  Icons.shopping_cart, Colors.green),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statCard('Revenue', '₹${_formatCompact(s['out_revenue'])}',
                  Icons.currency_rupee, Colors.orange),
              const SizedBox(width: 10),
              _statCard('Streak', '${s['out_streak'] ?? 0} days',
                  Icons.local_fire_department, Colors.red),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statCard('Badges', '${s['out_badges'] ?? 0}',
                  Icons.military_tech, Colors.purple),
              const SizedBox(width: 10),
              _statCard('Total XP', '$xp', Icons.bolt, Colors.amber.shade700),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: color)),
                  Text(label,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leaderboardTab() {
    return Column(
      children: [
        // Period selector
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _periodChip('weekly', 'This Week'),
              const SizedBox(width: 8),
              _periodChip('monthly', 'This Month'),
              const SizedBox(width: 8),
              _periodChip('daily', 'Today'),
            ],
          ),
        ),
        Expanded(
          child: _leaderboard.isEmpty
              ? const Center(
                  child: Text('No data for this period',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _leaderboard.length,
                  itemBuilder: (_, i) {
                    final e = _leaderboard[i];
                    final isMe = e['out_user_id'] == SupabaseService.userId;
                    const medals = ['🥇', '🥈', '🥉'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isMe
                                ? Colors.blue.shade300
                                : Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              i < 3 ? medals[i] : '#${i + 1}',
                              style: TextStyle(
                                  fontSize: i < 3 ? 22 : 14,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      e['out_full_name'] ?? '',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isMe
                                              ? Colors.blue.shade700
                                              : Colors.black87),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: const Text('YOU',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '📍${e['out_visits']} visits  •  📦${e['out_orders']} orders  •  💰₹${_formatCompact(e['out_revenue'])}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Text('${e['out_total_xp']}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.amber.shade700)),
                              Text('XP',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _periodChip(String value, String label) {
    final selected = _period == value;
    return GestureDetector(
      onTap: () {
        setState(() => _period = value);
        _loadLeaderboard();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? Colors.blue : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }

  Widget _milestonesTab() {
    if (_myMilestones.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No milestones yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Complete visits and orders to unlock milestones!',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myMilestones.length,
      itemBuilder: (_, i) {
        final m = _myMilestones[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Text(m['out_icon'] ?? '🏆', style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['out_title'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                        '${m['out_milestone_type']} • ${m['out_milestone_value']}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.check_circle, color: Colors.green.shade400, size: 24),
            ],
          ),
        );
      },
    );
  }

  String _formatCompact(dynamic n) {
    if (n == null) return '0';
    final v = double.tryParse(n.toString()) ?? 0;
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
