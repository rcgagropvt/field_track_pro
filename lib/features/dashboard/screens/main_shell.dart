import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/sync_status_banner.dart';
import '../../../core/widgets/vartmaan_logo.dart';
import '../../../router/app_router.dart';
import 'dashboard_screen.dart';
import '../../parties/screens/parties_screen.dart';
import '../../tracking/screens/tracking_screen.dart';
import '../../tasks/screens/tasks_screen.dart';
import '../../visits/screens/visit_history_screen.dart';
import '../../expenses/screens/expenses_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../orders/screens/order_history_screen.dart';
import '../../catalog/screens/product_catalog_screen.dart';
import '../../beats/screens/beat_plan_screen.dart';
import '../../targets/screens/target_screen.dart';
import '../../collections/screens/outstanding_screen.dart';
import '../../collections/screens/aging_analysis_screen.dart';
import '../../crm/screens/crm_screen.dart';
import '../../parties/screens/smart_planner_screen.dart';
import '../../gamification/screens/gamification_screen.dart';

// NOTE: PartyLedgerScreen requires a partyId argument — navigate to it
// from PartiesScreen or OutstandingScreen as a drill-down, not from
// the global drawer. It is NOT imported here.

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    PartiesScreen(),
    TrackingScreen(),
    VisitHistoryScreen(),
    TasksScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
                _buildNavItem(1, Icons.store_rounded, 'Parties'),
                _buildNavItem(2, Icons.location_on_rounded, 'Track'),
                _buildNavItem(3, Icons.assignment_turned_in_rounded, 'Visits'),
                _buildNavItem(4, Icons.task_alt_rounded, 'Tasks'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: isSelected ? AppColors.primary : AppColors.textTertiary),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration:
                  const BoxDecoration(gradient: AppColors.primaryGradient),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VartmaanLogo(size: 44, color: Colors.white),
                  SizedBox(height: 12),
                  VartmaanWordmark(
                    size: 32,
                    color: Colors.white,
                    textColor: Colors.white,
                  ),
                  SizedBox(height: 4),
                  Text('Field Sales Platform',
                      style: TextStyle(fontSize: 12, color: Colors.white60)),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(Icons.psychology, 'AI Smart Planner', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SmartPlannerScreen()));
                  }),
                  _drawerItem(Icons.emoji_events, 'Leaderboard & XP', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GamificationScreen()));
                  }),

                  const Divider(),

                  _drawerItem(Icons.track_changes, 'My Targets', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TargetScreen()));
                  }),
                  _drawerItem(Icons.payments_outlined, 'Outstanding', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OutstandingScreen()));
                  }),
                  _drawerItem(Icons.analytics_outlined, 'Aging Analysis', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AgingAnalysisScreen()));
                  }),
                  // Party Ledger is party-specific — accessible from
                  // Parties screen > party profile > ledger tab.
                  _drawerItem(Icons.inventory_2_outlined, 'Distributor Stock',
                      () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRouter.distributorStock);
                  }),
                  _drawerItem(Icons.route, 'Beat Plan', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BeatPlanScreen()));
                  }),
                  _drawerItem(Icons.receipt_long_rounded, 'Expenses', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ExpensesScreen()));
                  }),
                  _drawerItem(Icons.people_alt_rounded, 'CRM / Leads', () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CRMScreen()));
                  }),
                  _drawerItem(Icons.inventory_2_rounded, 'Product Catalog', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProductCatalogScreen()));
                  }),
                  _drawerItem(Icons.receipt_long_rounded, 'Orders', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OrderHistoryScreen()));
                  }),
                  _drawerItem(Icons.bar_chart_rounded, 'Reports', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReportsScreen()));
                  }),
                  _drawerItem(
                      Icons.event_available_rounded, 'Attendance History', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRouter.attendanceHistory);
                  }),
                  const Divider(),
                  _drawerItem(Icons.person_outline, 'Profile', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRouter.profile);
                  }),
                  _drawerItem(Icons.settings_outlined, 'Settings', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRouter.settings);
                  }),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Vartmaan Pulse v1.0.0',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textTertiary, size: 20),
      onTap: onTap,
    );
  }
}
