import 'package:flutter/material.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/dashboard/screens/main_shell.dart';
import '../features/tracking/screens/live_tracking_screen.dart';
import '../features/crm/screens/lead_detail_screen.dart';
import '../features/crm/screens/add_lead_screen.dart';
import '../features/tasks/screens/task_detail_screen.dart';
import '../features/expenses/screens/add_expense_screen.dart';
import '../features/attendance/screens/attendance_history_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../features/visits/screens/start_visit_screen.dart';
import '../features/visits/screens/visit_history_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/help_support_screen.dart';
import '../features/settings/screens/about_screen.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/admin_analytics_screen.dart';
import '../features/admin/screens/visit_analytics_screen.dart';
import '../features/admin/screens/admin_shell.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String main = '/main';
  static const String adminMain = '/admin-main'; // ← ADDED
  static const String liveTracking = '/live-tracking';
  static const String leadDetail = '/lead-detail';
  static const String addLead = '/add-lead';
  static const String taskDetail = '/task-detail';
  static const String addExpense = '/add-expense';
  static const String attendanceHistory = '/attendance-history';
  static const String profile = '/profile';
  static const String reports = '/reports';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String helpSupport = '/help-support';
  static const String about = '/about';
  static const String adminAnalytics = '/admin-analytics';
  static const String visitAnalytics = '/visit-analytics';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _fadeRoute(const SplashScreen());
      case login:
        return _slideRoute(const LoginScreen());
      case register:
        return _slideRoute(const RegisterScreen());
      case main:
        return _fadeRoute(const MainShell());
      case adminMain: // ← ADDED
        return _fadeRoute(const AdminShell()); // ← ADDED
      case liveTracking:
        return _slideRoute(const LiveTrackingScreen());
      case leadDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return _slideRoute(LeadDetailScreen(lead: args));
      case addLead:
        return _slideRoute(const AddLeadScreen());
      case taskDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return _slideRoute(TaskDetailScreen(task: args));
      case addExpense:
        return _slideRoute(const AddExpenseScreen());
      case attendanceHistory:
        return _slideRoute(const AttendanceHistoryScreen());
      case profile:
        return _slideRoute(const ProfileScreen());
      case reports:
        return _slideRoute(const ReportsScreen());
      case notifications:
        return _slideRoute(const NotificationsScreen());
      case AppRouter.settings:
        return _slideRoute(const SettingsScreen());
      case helpSupport:
        return _slideRoute(const HelpSupportScreen());
      case adminAnalytics:
        return _slideRoute(const AdminAnalyticsScreen());
      case visitAnalytics:
        return _slideRoute(const VisitAnalyticsScreen());
      case about:
        return _slideRoute(const AboutScreen());
      default:
        return _fadeRoute(
          Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }

  static PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static PageRouteBuilder _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
