import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../router/app_router.dart';
import '../../attendance/widgets/attendance_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/recent_activity_tile.dart';
import '../widgets/target_progress_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profile = await SupabaseService.getProfile();
      final stats = await SupabaseService.getDashboardStats();

      if (mounted) {
        setState(() {
          _profile = profile;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // ── 1. HEADER ──────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  greeting,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _profile?['full_name'] ?? 'Loading...',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Scaffold.of(context).openDrawer(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: const Icon(Icons.menu_rounded,
                                  color: AppColors.textPrimary, size: 22),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(
                                context, AppRouter.notifications),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: AppColors.textPrimary,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, AppRouter.profile),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primarySurface,
                              child: Text(
                                (_profile?['full_name'] ?? 'U')[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 24),

                      // ── 2. ATTENDANCE CARD ─────────────────────────────────
                      const AttendanceCard()
                          .animate(delay: 100.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.05),

                      const SizedBox(height: 24),

                      // ── 3. TODAY'S OVERVIEW ────────────────────────────────
                      const Text(
                        'Today\'s Overview',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.46,
                        children: [
                          StatCard(
                            title: 'Leads',
                            value: '${_stats?['total_leads'] ?? 0}',
                            icon: Icons.people_alt_rounded,
                            color: AppColors.info,
                            subtitle: 'Total active',
                          ),
                          StatCard(
                            title: 'Tasks',
                            value: '${_stats?['pending_tasks'] ?? 0}',
                            icon: Icons.task_alt_rounded,
                            color: AppColors.warning,
                            subtitle: 'Pending',
                          ),
                          StatCard(
                            title: 'Visits',
                            value: '${_stats?['today_visits'] ?? 0}',
                            icon: Icons.place_rounded,
                            color: AppColors.success,
                            subtitle: 'Today',
                          ),
                          StatCard(
                            title: 'Distance',
                            value: '0 km',
                            icon: Icons.route_rounded,
                            color: AppColors.primary,
                            subtitle: 'Traveled today',
                          ),
                        ],
                      )
                          .animate(delay: 200.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.05),

                      const SizedBox(height: 24),

                      // ── 4. THIS MONTH'S TARGET ─────────────────────────────
                      const Text(
                        'This Month\'s Target',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const TargetProgressCard()
                          .animate(delay: 250.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.05),

                      const SizedBox(height: 24),

                      // ── 5. QUICK ACTIONS ───────────────────────────────────
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            QuickActionButton(
                              icon: Icons.person_add_alt_1_rounded,
                              label: 'New Lead',
                              color: AppColors.leadNew,
                              onTap: () => Navigator.pushNamed(
                                  context, AppRouter.addLead),
                            ),
                            const SizedBox(width: 12),
                            QuickActionButton(
                              icon: Icons.map_rounded,
                              label: 'Live Track',
                              color: AppColors.primary,
                              onTap: () => Navigator.pushNamed(
                                  context, AppRouter.liveTracking),
                            ),
                            const SizedBox(width: 12),
                            QuickActionButton(
                              icon: Icons.add_card_rounded,
                              label: 'Add Expense',
                              color: AppColors.warning,
                              onTap: () => Navigator.pushNamed(
                                  context, AppRouter.addExpense),
                            ),
                            const SizedBox(width: 12),
                            QuickActionButton(
                              icon: Icons.bar_chart_rounded,
                              label: 'Reports',
                              color: AppColors.success,
                              onTap: () => Navigator.pushNamed(
                                  context, AppRouter.reports),
                            ),
                            const SizedBox(width: 12),
                            QuickActionButton(
                              icon: Icons.shopping_cart_rounded,
                              label: 'Orders',
                              color: AppColors.leadContacted,
                              onTap: () => Navigator.pushNamed(
                                  context, AppRouter.orderHistory),
                            ),
                          ],
                        ),
                      )
                          .animate(delay: 300.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.05),

                      const SizedBox(height: 24),

                      // ── 6. RECENT ACTIVITY ─────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Activity',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, AppRouter.reports),
                            child: const Text('See All'),
                          ),
                        ],
                      ),

                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: SupabaseService.client
                            .from('visits')
                            .select('party_name, status, check_in_time')
                            .eq('user_id', SupabaseService.userId ?? '')
                            .order('created_at', ascending: false)
                            .limit(5),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: const Center(
                                child: Text(
                                  'No recent activity yet.\nStart visiting parties!',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(color: AppColors.textTertiary),
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: snapshot.data!.map((visit) {
                              final time = visit['check_in_time'] != null
                                  ? DateFormat('hh:mm a').format(
                                      DateTime.parse(visit['check_in_time']))
                                  : '';
                              return RecentActivityTile(
                                icon: visit['status'] == 'completed'
                                    ? Icons.check_circle_rounded
                                    : Icons.storefront_rounded,
                                title: visit['party_name'] ?? 'Visit',
                                subtitle: (visit['status'] ?? '')
                                    .toString()
                                    .replaceAll('_', ' '),
                                time: time,
                                color: visit['status'] == 'completed'
                                    ? AppColors.success
                                    : AppColors.info,
                              );
                            }).toList(),
                          );
                        },
                      )
                          .animate(delay: 400.ms)
                          .fadeIn(duration: 300.ms)
                          .slideX(begin: 0.05),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}
