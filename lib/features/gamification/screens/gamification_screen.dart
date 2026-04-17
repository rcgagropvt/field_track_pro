import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class GamificationScreen extends StatefulWidget {
  const GamificationScreen({super.key});
  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;

  // My stats
  int _totalXp = 0;
  int _todayXp = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  String _level = 'Rookie';
  int _rank = 0;
  List<Map<String, dynamic>> _badges = [];
  List<Map<String, dynamic>> _recentXp = [];

  // Leaderboard
  List<Map<String, dynamic>> _leaderboard = [];
  String _period = 'monthly';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadMyStats(), _loadLeaderboard()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMyStats() async {
    try {
      final uid = SupabaseService.userId;
      if (uid == null) return;

      final results = await Future.wait([
        // Total XP
        SupabaseService.client
            .from('gamification_xp')
            .select('xp_amount')
            .eq('user_id', uid),
        // Today XP
        SupabaseService.client
            .from('gamification_xp')
            .select('xp_amount')
            .eq('user_id', uid)
            .gte('created_at', DateTime.now().toIso8601String().substring(0, 10)),
        // Badges
        SupabaseService.client
            .from('gamification_badges')
            .select()
            .eq('user_id', uid)
            .order('earned_at', ascending: false),
        // Streak
        SupabaseService.client
            .from('gamification_streaks')
            .select()
            .eq('user_id', uid)
            .eq('streak_type', 'daily_visits')
            .maybeSingle(),
        // Recent XP
        SupabaseService.client
            .from('gamification_xp')
            .select()
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(20),
      ]);

      final allXp = List<Map<String, dynamic>>.from(results[0] as List);
      final todayXp = List<Map<String, dynamic>>.from(results[1] as List);
      final badges = List<Map<String, dynamic>>.from(results[2] as List);
      final streak = results[3] as Map<String, dynamic>?;
      final recent = List<Map<String, dynamic>>.from(results[4] as List);

      final total = allXp.fold<int>(0, (s, e) => s + ((e['xp_amount'] as num?)?.toInt() ?? 0));
      final today = todayXp.fold<int>(0, (s, e) => s + ((e['xp_amount'] as num?)?.toInt() ?? 0));

      if (mounted) {
        setState(() {
          _totalXp = total;
          _todayXp = today;
          _badges = badges;
          _currentStreak = (streak?['current_streak'] as int?) ?? 0;
          _longestStreak = (streak?['longest_streak'] as int?) ?? 0;
          _recentXp = recent;
          _level = total >= 5000
              ? 'Sales Legend'
              : total >= 2000
                  ? 'Territory Champion'
                  : total >= 500
                      ? 'Field Star'
                      : 'Rookie';
        });
      }
    } catch (e) {
      debugPrint('Gamification stats error: $e');
    }
  }

  Future<void> _loadLeaderboard() async {
    try {
      final data = await SupabaseService.client
          .rpc('gamification_leaderboard', params: {'p_period': _period}) as List;
      final list = List<Map<String, dynamic>>.from(data);

      final uid = SupabaseService.userId;
      final myEntry = list.indexWhere((e) => e['out_user_id'] == uid);

      if (mounted) {
        setState(() {
          _leaderboard = list;
          _rank = myEntry >= 0 ? myEntry + 1 : 0;
        });
      }
    } catch (e) {
      debugPrint('Leaderboard error: $e');
    }
  }

  int get _xpToNextLevel {
    if (_totalXp >= 5000) return 0;
    if (_totalXp >= 2000) return 5000 - _totalXp;
    if (_totalXp >= 500) return 2000 - _totalXp;
    return 500 - _totalXp;
  }

  double get _levelProgress {
    if (_totalXp >= 5000) return 1.0;
    if (_totalXp >= 2000) return (_totalXp - 2000) / 3000;
    if (_totalXp >= 500) return (_totalXp - 500) / 1500;
    return _totalXp / 500;
  }

  String get _nextLevel {
    if (_totalXp >= 5000) return 'Max Level';
    if (_totalXp >= 2000) return 'Sales Legend';
    if (_totalXp >= 500) return 'Territory Champion';
    return 'Field Star';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1123),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1123),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFD700)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.emoji_events, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text('Leaderboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _loadAll),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFFFFD700),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'My Stats'),
            Tab(text: 'Leaderboard'),
            Tab(text: 'Badges'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : TabBarView(controller: _tabCtrl, children: [
              _myStatsTab(),
              _leaderboardTab(),
              _badgesTab(),
            ]),
    );
  }

  // ═══════════════════════════════════════
  // TAB 1: MY STATS
  // ═══════════════════════════════════════
  Widget _myStatsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Level card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2140), Color(0xFF2A1F5E)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
            ),
            child: Column(children: [
              Text(_level,
                  style: const TextStyle(
                      color: Color(0xFFFFD700), fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('$_totalXp XP',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _levelProgress,
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _xpToNextLevel > 0 ? '$_xpToNextLevel XP to $_nextLevel' : 'Maximum level reached!',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ]),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: 16),

          // Stats row
          Row(children: [
            _statCard('Today', '$_todayXp XP', Icons.today, Colors.blue),
            const SizedBox(width: 10),
            _statCard('Rank', _rank > 0 ? '#$_rank' : '-', Icons.leaderboard, Colors.orange),
            const SizedBox(width: 10),
            _statCard('Streak', '$_currentStreak days', Icons.local_fire_department, Colors.red),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _statCard('Longest', '$_longestStreak days', Icons.emoji_events, const Color(0xFFFFD700)),
            const SizedBox(width: 10),
            _statCard('Badges', '${_badges.length}', Icons.military_tech, Colors.purple),
            const SizedBox(width: 10),
            _statCard('Level', _level.split(' ').first, Icons.star, Colors.teal),
          ]),
          const SizedBox(height: 20),

          // Recent activity
          Row(children: [
            const Text('RECENT XP',
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const Spacer(),
          ]),
          const SizedBox(height: 8),
          ..._recentXp.take(10).map((xp) {
            final action = xp['action']?.toString() ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(_actionIcon(action), size: 16, color: _actionColor(action)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    xp['description']?.toString() ?? _actionLabel(action),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('+${xp['xp_amount']} XP',
                    style: TextStyle(
                        color: _actionColor(action), fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 9)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB 2: LEADERBOARD
  // ═══════════════════════════════════════
  Widget _leaderboardTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Period selector
          Row(children: [
            _periodChip('daily', 'Today'),
            const SizedBox(width: 8),
            _periodChip('weekly', 'This Week'),
            const SizedBox(width: 8),
            _periodChip('monthly', 'This Month'),
          ]),
          const SizedBox(height: 16),

          // Podium (top 3)
          if (_leaderboard.length >= 3)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _podiumSpot(_leaderboard[1], 2, 90, Colors.grey.shade400),
                const SizedBox(width: 8),
                _podiumSpot(_leaderboard[0], 1, 110, const Color(0xFFFFD700)),
                const SizedBox(width: 8),
                _podiumSpot(_leaderboard[2], 3, 70, Colors.brown.shade300),
              ],
            ),
          const SizedBox(height: 20),

          // Full list
          ..._leaderboard.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final isMe = e['out_user_id'] == SupabaseService.userId;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF2A1F5E) : const Color(0xFF1A1D2E),
                borderRadius: BorderRadius.circular(12),
                border: isMe ? Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)) : null,
              ),
              child: Row(children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    i < 3 ? ['🥇', '🥈', '🥉'][i] : '#${i + 1}',
                    style: TextStyle(
                        fontSize: i < 3 ? 18 : 13,
                        color: Colors.white54,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isMe ? const Color(0xFFFFD700) : Colors.blue.shade800,
                  child: Text(
                    (e['out_user_name']?.toString() ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                        color: isMe ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(e['out_user_name']?.toString() ?? '',
                          style: TextStyle(
                              color: isMe ? const Color(0xFFFFD700) : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      if (isMe)
                        const Text(' (You)',
                            style: TextStyle(color: Color(0xFFFFD700), fontSize: 10)),
                    ]),
                    Text(
                      '${e['out_visits']} visits · ${e['out_orders']} orders · ${e['out_streak']}d streak',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${e['out_total_xp']} XP',
                      style: const TextStyle(
                          color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(e['out_level']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white30, fontSize: 9)),
                ]),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _periodChip(String value, String label) {
    final selected = _period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _period = value);
          _loadLeaderboard();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFD700).withOpacity(0.15) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? const Color(0xFFFFD700).withOpacity(0.5) : Colors.transparent),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  color: selected ? const Color(0xFFFFD700) : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ),
      ),
    );
  }

  Widget _podiumSpot(Map<String, dynamic> e, int rank, double height, Color color) {
    final name = (e['out_user_name']?.toString() ?? 'U').split(' ').first;
    return Column(children: [
      CircleAvatar(
        radius: rank == 1 ? 28 : 22,
        backgroundColor: color,
        child: Text(name[0].toUpperCase(),
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: rank == 1 ? 20 : 16)),
      ),
      const SizedBox(height: 6),
      Text(name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
      Text('${e['out_total_xp']} XP',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
      const SizedBox(height: 4),
      Container(
        width: 70,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Center(
          child: Text('#$rank',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
      ),
    ]);
  }

  // ═══════════════════════════════════════
  // TAB 3: BADGES
  // ═══════════════════════════════════════
  Widget _badgesTab() {
    final allBadges = [
      {'key': 'first_visit', 'name': 'First Steps', 'icon': '👣', 'desc': 'Complete your first visit'},
      {'key': 'visit_50', 'name': 'Road Warrior', 'icon': '🚗', 'desc': '50 visits completed'},
      {'key': 'visit_100', 'name': 'Century Club', 'icon': '💯', 'desc': '100 visits completed'},
      {'key': 'visit_500', 'name': 'Field Legend', 'icon': '🏆', 'desc': '500 visits completed'},
      {'key': 'order_10', 'name': 'Deal Maker', 'icon': '🤝', 'desc': '10 orders placed'},
      {'key': 'order_50', 'name': 'Sales Machine', 'icon': '⚡', 'desc': '50 orders placed'},
      {'key': 'order_100', 'name': 'Order King', 'icon': '👑', 'desc': '100 orders placed'},
      {'key': 'streak_5', 'name': 'On Fire', 'icon': '🔥', 'desc': '5-day visit streak'},
      {'key': 'streak_15', 'name': 'Unstoppable', 'icon': '💪', 'desc': '15-day visit streak'},
      {'key': 'streak_30', 'name': 'Iron Will', 'icon': '🏅', 'desc': '30-day visit streak'},
      {'key': 'xp_500', 'name': 'Rising Star', 'icon': '⭐', 'desc': 'Earn 500 XP'},
      {'key': 'xp_2000', 'name': 'Superstar', 'icon': '🌟', 'desc': 'Earn 2000 XP'},
      {'key': 'xp_5000', 'name': 'MVP', 'icon': '🎖️', 'desc': 'Earn 5000 XP'},
      {'key': 'parties_10', 'name': 'Network Builder', 'icon': '🌐', 'desc': 'Manage 10 parties'},
      {'key': 'parties_50', 'name': 'Territory Master', 'icon': '🗺️', 'desc': 'Manage 50 parties'},
    ];

    final earnedKeys = _badges.map((b) => b['badge_key']).toSet();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${earnedKeys.length} / ${allBadges.length} Earned',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: allBadges.length,
          itemBuilder: (_, i) {
            final b = allBadges[i];
            final earned = earnedKeys.contains(b['key']);
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: earned ? const Color(0xFF1E2140) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: earned ? const Color(0xFFFFD700).withOpacity(0.4) : Colors.white10,
                ),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(b['icon'] as String,
                    style: TextStyle(fontSize: 28, color: earned ? null : Colors.grey)),
                const SizedBox(height: 6),
                Text(b['name'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: earned ? Colors.white : Colors.white30,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    )),
                Text(b['desc'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: earned ? Colors.white38 : Colors.white12, fontSize: 8)),
              ]),
            );
          },
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════
  IconData _actionIcon(String action) {
    switch (action) {
      case 'visit_completed': return Icons.place;
      case 'order_placed': return Icons.shopping_cart;
      case 'payment_collected': return Icons.payments;
      case 'new_party_added': return Icons.person_add;
      case 'stock_check': return Icons.inventory;
      case 'on_time_checkin': return Icons.access_time;
      case 'geofence_compliant': return Icons.gps_fixed;
      case 'streak_bonus': return Icons.local_fire_department;
      default: return Icons.star;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'visit_completed': return Colors.blue;
      case 'order_placed': return Colors.green;
      case 'payment_collected': return Colors.teal;
      case 'new_party_added': return Colors.purple;
      case 'streak_bonus': return Colors.orange;
      default: return const Color(0xFFFFD700);
    }
  }

  String _actionLabel(String action) {
    return action.replaceAll('_', ' ').toUpperCase();
  }
}
