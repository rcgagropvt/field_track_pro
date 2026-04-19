import 'package:flutter/material.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/dashboard/screens/main_shell.dart';
import '../features/tracking/screens/live_tracking_screen.dart';
import '../features/crm/screens/lead_detail_screen.dart';
import '../features/crm/screens/add_lead_screen.dart';
import '../features/tasks/screens/task_detail_screen.dart';
import '../features/tasks/screens/add_task_screen.dart';
import '../features/expenses/screens/add_expense_screen.dart';
import '../features/attendance/screens/attendance_history_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/help_support_screen.dart';
import '../features/settings/screens/about_screen.dart';
import '../features/admin/screens/admin_analytics_screen.dart';
import '../features/admin/screens/visit_analytics_screen.dart';
import '../features/admin/screens/admin_shell.dart';
import '../features/admin/screens/advanced_analytics_screen.dart';
import '../features/admin/screens/ai_command_center_screen.dart'; // class: AiCommandCenterScreen
import '../features/admin/screens/admin_loyalty_screen.dart';
import '../features/admin/screens/employee_detail_screen.dart';
import '../features/admin/screens/ai_chat_screen.dart';
import '../features/catalog/screens/product_catalog_screen.dart';
import '../features/catalog/screens/manage_products_screen.dart';
import '../features/orders/screens/order_booking_screen.dart';
import '../features/orders/screens/order_history_screen.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/orders/screens/ai_suggested_order_screen.dart';
import '../features/beats/screens/beat_plan_screen.dart';
import '../features/beats/screens/beat_list_screen.dart';
import '../features/beats/screens/create_beat_screen.dart';
import '../features/beats/screens/optimized_route_screen.dart';
import '../features/schemes/screens/scheme_list_screen.dart';
import '../features/schemes/screens/create_scheme_screen.dart';
import '../features/stock/screens/stock_check_screen.dart';
import '../features/stock/screens/distributor_stock_screen.dart';
import '../features/gamification/screens/gamification_screen.dart';
import '../features/gamification/screens/hall_of_fame_screen.dart';
import '../features/parties/screens/smart_planner_screen.dart';
import '../features/auth/screens/welcome_screen.dart';

class AppRouter {
  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // ── Shells ────────────────────────────────────────────────────────────────
  static const String main = '/main';
  static const String adminMain = '/admin-main';

  // ── Field rep ─────────────────────────────────────────────────────────────
  static const String liveTracking = '/live-tracking';
  static const String attendanceHistory = '/attendance-history';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String reports = '/reports';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String helpSupport = '/help-support';
  static const String about = '/about';

  // ── CRM ───────────────────────────────────────────────────────────────────
  static const String leadDetail = '/lead-detail';
  static const String addLead = '/add-lead';

  // ── Tasks ─────────────────────────────────────────────────────────────────
  static const String taskDetail = '/task-detail';
  static const String addTask = '/add-task';

  // ── Expenses ──────────────────────────────────────────────────────────────
  static const String addExpense = '/add-expense';

  // ── Orders & Catalog ──────────────────────────────────────────────────────
  static const String productCatalog = '/product-catalog';
  static const String orderBooking = '/order-booking';
  static const String orderHistory = '/order-history';
  static const String orderDetail = '/order-detail';
  static const String manageProducts = '/manage-products';
  static const String aiSuggestedOrder = '/ai-suggested-order';

  // ── Beats ─────────────────────────────────────────────────────────────────
  static const String beatPlan = '/beat-plan';
  static const String beatList = '/beat-list';
  static const String createBeat = '/create-beat';
  static const String optimizedRoute = '/optimized-route';

  // ── Schemes ───────────────────────────────────────────────────────────────
  static const String schemeList = '/scheme-list';
  static const String createScheme = '/create-scheme';

  // ── Stock ─────────────────────────────────────────────────────────────────
  static const String stockCheck = '/stock-check';
  static const String distributorStock = '/distributor-stock';

  // ── Gamification ──────────────────────────────────────────────────────────
  static const String gamification = '/gamification';
  static const String hallOfFame = '/hall-of-fame';

  // ── Admin ─────────────────────────────────────────────────────────────────
  static const String adminAnalytics = '/admin-analytics';
  static const String visitAnalytics = '/visit-analytics';
  static const String advancedAnalytics = '/advanced-analytics';
  static const String aiCommandCenter = '/ai-command-center';
  static const String adminLoyalty = '/admin-loyalty';
  static const String employeeDetail = '/employee-detail';
  static const String aiChat = '/ai-chat';
  static const String smartPlanner = '/smart-planner';
  static const String welcome = '/welcome';

  // ─────────────────────────────────────────────────────────────────────────
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ── Auth ─────────────────────────────────────────────────────────────
      case splash:
        return _fadeRoute(const SplashScreen());
      case login:
        return _slideRoute(const LoginScreen());
      case register:
        return _slideRoute(const RegisterScreen());

      // ── Shells ───────────────────────────────────────────────────────────
      case main:
        return _fadeRoute(const MainShell());
      case adminMain:
        return _fadeRoute(const AdminShell());

      // ── Field rep ────────────────────────────────────────────────────────
      case liveTracking:
        return _slideRoute(const LiveTrackingScreen());
      case attendanceHistory:
        return _slideRoute(const AttendanceHistoryScreen());
      case profile:
        return _slideRoute(const ProfileScreen());
      case editProfile:
        // Usage: Navigator.pushNamed(context, AppRouter.editProfile,
        //          arguments: profileMap);   // Map<String, dynamic>
        final args = settings.arguments as Map<String, dynamic>;
        return _slideRoute(EditProfileScreen(profile: args));
      case reports:
        return _slideRoute(const ReportsScreen());
      case notifications:
        return _slideRoute(const NotificationsScreen());
      case AppRouter.settings:
        return _slideRoute(const SettingsScreen());
      case helpSupport:
        return _slideRoute(const HelpSupportScreen());
      case about:
        return _slideRoute(const AboutScreen());

      // ── CRM ──────────────────────────────────────────────────────────────
      case leadDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return _slideRoute(LeadDetailScreen(lead: args));
      case addLead:
        return _slideRoute(const AddLeadScreen());

      // ── Tasks ────────────────────────────────────────────────────────────
      case taskDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return _slideRoute(TaskDetailScreen(task: args));
      case addTask:
        return _slideRoute(const AddTaskScreen());

      // ── Expenses ─────────────────────────────────────────────────────────
      case addExpense:
        return _slideRoute(const AddExpenseScreen());

      // ── Orders & Catalog ─────────────────────────────────────────────────
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
      case aiSuggestedOrder:
        // Usage: Navigator.pushNamed(context, AppRouter.aiSuggestedOrder,
        //          arguments: partyMap);   // Map<String, dynamic> — full party row
        // Returns: List<Map<String,dynamic>> cart items via Navigator.pop(context, cartItems)
        final args = settings.arguments as Map<String, dynamic>;
        return _slideRoute(AiSuggestedOrderScreen(party: args));

      // ── Beats ────────────────────────────────────────────────────────────
      case beatPlan:
        return _slideRoute(const BeatPlanScreen());
      case beatList:
        return _slideRoute(const BeatListScreen());
      case createBeat:
        return _slideRoute(const CreateBeatScreen());
      case optimizedRoute:
        return _slideRoute(const OptimizedRouteScreen());

      // ── Schemes ──────────────────────────────────────────────────────────
      case schemeList:
        return _slideRoute(const SchemeListScreen());
      case createScheme:
        return _slideRoute(const CreateSchemeScreen());

      // ── Stock ────────────────────────────────────────────────────────────
      case stockCheck:
        final args = settings.arguments as Map<String, dynamic>;
        return _slideRoute(StockCheckScreen(
          party: args['party'],
          visitId: args['visit_id'] as String?,
        ));
      case distributorStock:
        return _slideRoute(const DistributorStockScreen());

      // ── Gamification ─────────────────────────────────────────────────────
      case gamification:
        return _slideRoute(const GamificationScreen());
      case hallOfFame:
        return _slideRoute(const HallOfFameScreen());

      // ── Admin ────────────────────────────────────────────────────────────
      case adminAnalytics:
        return _slideRoute(const AdminAnalyticsScreen());
      case visitAnalytics:
        return _slideRoute(const VisitAnalyticsScreen());
      case advancedAnalytics:
        return _slideRoute(const AdvancedAnalyticsScreen());
      case aiCommandCenter:
        return _slideRoute(const AiCommandCenterScreen());
      case adminLoyalty:
        return _slideRoute(const AdminLoyaltyScreen());
      case employeeDetail:
        // Usage: Navigator.pushNamed(context, AppRouter.employeeDetail,
        //          arguments: employeeMap);   // Map<String, dynamic> — full employee row
        final args = settings.arguments as Map<String, dynamic>;
        return _slideRoute(EmployeeDetailScreen(employee: args));
      case aiChat:
        return _slideRoute(const AiChatScreen());
      case smartPlanner:
        // SmartPlannerScreen fetches its own data via SupabaseService RPC.
        // No arguments needed.
        return _slideRoute(const SmartPlannerScreen());
      case welcome:
        return _fadeRoute(const WelcomeScreen());

      // ── Fallback ─────────────────────────────────────────────────────────
      default:
        return _fadeRoute(
          Scaffold(
            body: Center(
              child: Text(
                'No route defined for: ${settings.name}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
    }
  }

  // ── Transitions ───────────────────────────────────────────────────────────
  static PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static PageRouteBuilder _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: Curves.easeInOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
