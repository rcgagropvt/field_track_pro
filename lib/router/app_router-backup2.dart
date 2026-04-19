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
import '../features/catalog/screens/product_catalog_screen.dart';
import '../features/orders/screens/order_booking_screen.dart';
import '../features/orders/screens/order_history_screen.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/catalog/screens/manage_products_screen.dart';
import '../features/beats/screens/beat_plan_screen.dart';
import '../features/beats/screens/beat_list_screen.dart';
import '../features/beats/screens/create_beat_screen.dart';
import '../features/schemes/screens/scheme_list_screen.dart';
import '../features/schemes/screens/create_scheme_screen.dart';
import '../features/admin/screens/advanced_analytics_screen.dart';
import '../features/beats/screens/optimized_route_screen.dart';
// Sprint 7: Stock management
import '../features/stock/screens/stock_check_screen.dart';
import '../features/stock/screens/distributor_stock_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String main = '/main';
  static const String adminMain = '/admin-main';
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
  static const String productCatalog = '/product-catalog';
  static const String orderBooking = '/order-booking';
  static const String orderHistory = '/order-history';
  static const String orderDetail = '/order-detail';
  static const String manageProducts = '/manage-products';
  static const String beatPlan = '/beat-plan';
  static const String beatList = '/beat-list';
  static const String createBeat = '/create-beat';
  static const String schemeList = '/scheme-list';
  static const String advancedAnalytics = '/advanced-analytics';
  static const String optimizedRoute = '/optimized-route';
  // Sprint 7
  static const String stockCheck = '/stock-check';
  static const String distributorStock = '/distributor-stock';

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
      case adminMain:
        return _fadeRoute(const AdminShell());
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
      case productCatalog:
        return _slideRoute(const ProductCatalogScreen());
      case orderBooking:
        final args = settings.arguments as Map<String, dynamic>;
        return _slideRoute(OrderBookingScreen(
          party: args['party'],
          visitId: args['visit_id'] as String?,
        ));
      case orderHistory:
        return _slideRoute(const OrderHistoryScreen());
      case orderDetail:
        final args = settings.arguments as String;
        return _slideRoute(OrderDetailScreen(orderId: args));
      case manageProducts:
        return _slideRoute(const ManageProductsScreen());
      case beatPlan:
        return _slideRoute(const BeatPlanScreen());
      case beatList:
        return _slideRoute(const BeatListScreen());
      case createBeat:
        return _slideRoute(const CreateBeatScreen());
      case schemeList:
        return _slideRoute(const SchemeListScreen());
      case advancedAnalytics:
        return _slideRoute(const AdvancedAnalyticsScreen());
      case optimizedRoute:
        return _slideRoute(const OptimizedRouteScreen());

      // ── Sprint 7 ───────────────────────────────────────────────────────
      case stockCheck:
        final args = settings.arguments as Map<String, dynamic>;
        return _slideRoute(StockCheckScreen(
          party: args['party'],
          visitId: args['visit_id'] as String?,
        ));
      case distributorStock:
        return _slideRoute(const DistributorStockScreen());

      default:
        return _fadeRoute(
          Scaffold(
            body: Center(
                child: Text('Route not found: ${settings.name}')),
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
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: curve));
        return SlideTransition(
            position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
