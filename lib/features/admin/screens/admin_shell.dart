import 'package:flutter/material.dart';
import 'package:vartmaan_pulse/core/services/supabase_service.dart';

import 'admin_dashboard_screen.dart';
import 'employee_list_screen.dart';
import 'live_map_screen.dart';
import 'expense_approval_screen.dart';
import 'assign_task_screen.dart';
import 'admin_analytics_screen.dart';
import 'visit_analytics_screen.dart';
import 'create_employee_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_settings_screen.dart';
import 'about_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_collections_screen.dart';

import '../../catalog/screens/manage_products_screen.dart';
import '../../beats/screens/beat_list_screen.dart';
import '../../targets/screens/admin_targets_screen.dart';
import '../../targets/screens/set_targets_screen.dart';
import '../../schemes/screens/scheme_list_screen.dart';
import '../../collections/screens/aging_analysis_screen.dart';
import '../../collections/screens/outstanding_screen.dart';

import '../../parties/screens/admin_parties_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;
  Map<String, dynamic> _adminProfile = {};

  final List<Widget> _screens = const [
    AdminDashboardScreen(), // 0
    EmployeeListScreen(), // 1
    LiveMapScreen(), // 2
    VisitAnalyticsScreen(), // 3
    ExpenseApprovalScreen(), // 4
    AdminAnalyticsScreen(), // 5
    AssignTaskScreen(), // 6
    ManageProductsScreen(), // 7
    CreateEmployeeScreen(), // 8
    AdminProfileScreen(), // 9
    AdminSettingsScreen(), // 10
    AboutScreen(), // 11
    AdminOrdersScreen(), // 12  ← NEW
    BeatListScreen(),
    AdminTargetsScreen(),
    SchemeListScreen(),
    AdminCollectionsScreen(),
    AgingAnalysisScreen(),
    OutstandingScreen(), // 19 ← NEW
    AdminPartiesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) return;
    final data = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('id', uid)
        .single();
    setState(() => _adminProfile = data);
  }

  void _navigate(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AdminShell.scaffoldKey,
      drawer: _buildDrawer(),
      body: IndexedStack(index: _currentIndex, children: _screens),
    );
  }

  Widget _buildDrawer() {
    final name = _adminProfile['full_name'] ?? 'Admin';
    final email = _adminProfile['email'] ??
        SupabaseService.client.auth.currentUser?.email ??
        '';

    return Drawer(
      backgroundColor: const Color(0xFF1A1D2E),
      child: SafeArea(
        child: Column(
          children: [
            // Profile header
            GestureDetector(
              onTap: () => _navigate(9),
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF252840),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue.shade700,
                    child: Text(name[0].toUpperCase(),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                      Text(email,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Administrator',
                            style: TextStyle(
                                color: Colors.blue,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  )),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                ]),
              ),
            ),

            // Nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _navItem(Icons.dashboard_rounded, 'Dashboard', 0),
                  const SizedBox(height: 4),

                  _sectionLabel('FIELD OPERATIONS'),
                  _expandable(
                    icon: Icons.location_on,
                    label: 'Field Operations',
                    color: Colors.orange,
                    children: [
                      _subItem(Icons.people, 'All Employees', 1),
                      _subItem(Icons.store_rounded, 'All Parties', 19),
                      _subItem(Icons.map, 'Live Map', 2),
                      _subItem(Icons.store, 'Visit Analytics', 3),
                      _subItem(Icons.route, 'Beat Plans', 13),
                    ],
                  ),

                  _sectionLabel('FINANCE'),
                  _expandable(
                    icon: Icons.receipt_long,
                    label: 'Finance',
                    color: Colors.green,
                    children: [
                      _subItem(Icons.shopping_cart, 'All Orders', 12),
                      _subItem(Icons.local_offer_rounded, 'Schemes & Offers',
                          15), // ← ADD
                      _subItem(Icons.payments_rounded, 'Collections', 16),
                      _subItem(Icons.bar_chart_rounded, 'Aging Analysis', 17),
                      _subItem(Icons.account_balance_wallet, 'Outstanding', 18),
                      _subItem(
                          Icons.check_circle_outline, 'Expense Approvals', 4),
                      _subItem(Icons.analytics, 'Analytics Report', 5),
                    ],
                  ),

                  _sectionLabel('HR MANAGEMENT'),
                  _expandable(
                    icon: Icons.manage_accounts,
                    label: 'HR Management',
                    color: Colors.purple,
                    children: [
                      _subItem(Icons.person_add, 'Create Employee', 8),
                      _subItem(Icons.people_alt, 'Manage Employees', 1),
                      _subItem(Icons.assignment, 'Assign Task', 6),
                      _subItem(Icons.inventory_2, 'Manage Products', 7),
                      _subItem(Icons.track_changes, 'Set Targets', 14),
                    ],
                  ),

                  _sectionLabel('ACCOUNT'),
                  _expandable(
                    icon: Icons.person,
                    label: 'Account',
                    color: Colors.teal,
                    children: [
                      _subItem(Icons.manage_accounts, 'My Profile', 9),
                      _subItem(Icons.settings, 'Settings', 10),
                    ],
                  ),

                  const SizedBox(height: 8),
                  _navItem(Icons.info_outline, 'About', 11),
                  const Divider(color: Colors.white12, height: 24),

                  // Sign out
                  ListTile(
                    leading: const Icon(Icons.logout,
                        color: Colors.redAccent, size: 20),
                    title: const Text('Sign Out',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500)),
                    onTap: () async {
                      Navigator.pop(context);
                      await SupabaseService.client.auth.signOut();
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Text(label,
            style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
      );

  Widget _navItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading:
          Icon(icon, color: isActive ? Colors.blue : Colors.grey, size: 20),
      title: Text(label,
          style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14)),
      tileColor: isActive ? Colors.blue.withOpacity(0.15) : Colors.transparent,
      onTap: () => _navigate(index),
    );
  }

  Widget _expandable({
    required IconData icon,
    required String label,
    required Color color,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(label,
            style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.normal)),
        iconColor: Colors.grey,
        collapsedIconColor: Colors.grey,
        childrenPadding: const EdgeInsets.only(left: 16),
        children: children,
      ),
    );
  }

  Widget _subItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Icon(icon,
          size: 18,
          color: isActive ? Colors.blue.shade300 : Colors.grey.shade600),
      title: Text(label,
          style: TextStyle(
              fontSize: 13,
              color: isActive ? Colors.blue.shade300 : Colors.grey.shade400,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
      tileColor: isActive ? Colors.blue.withOpacity(0.1) : Colors.transparent,
      onTap: () => _navigate(index),
    );
  }
}
