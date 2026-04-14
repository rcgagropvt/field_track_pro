import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'dashboard_screen.dart';
import '../../parties/screens/parties_screen.dart';
import '../../tracking/screens/tracking_screen.dart';
import '../../crm/screens/crm_screen.dart';
import '../../tasks/screens/tasks_screen.dart';
import '../../visits/screens/visit_history_screen.dart';
import '../../expenses/screens/expenses_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../router/app_router.dart';

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
      body: IndexedStack(index: _currentIndex, children: _screens),

      // Drawer for extra features
      drawer: _buildDrawer(),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
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
            // Drawer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_rounded,
                      size: 36, color: AppColors.white),
                  SizedBox(height: 12),
                  Text('FieldTrack Pro',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white)),
                  Text('Menu',
                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
            ),

            const SizedBox(height: 8),

            _drawerItem(Icons.receipt_long_rounded, 'Expenses', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ExpensesScreen()));
            }),
            _drawerItem(Icons.people_alt_rounded, 'CRM / Leads', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CRMScreen()));
            }),
            _drawerItem(Icons.bar_chart_rounded, 'Reports', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()));
            }),
            _drawerItem(Icons.event_available_rounded, 'Attendance History',
                () {
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
              Navigator.pushNamed(context, AppRouter.settings); // was empty
            }),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('FieldTrack Pro v1.0.0',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textTertiary)),
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
