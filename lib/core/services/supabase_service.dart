import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static String? get userId => currentUser?.id;
  static bool get isAuthenticated => currentUser != null;

  // ── Auth ──────────────────────────────────────────────
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String role = 'employee',
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': role},
    );

    // Create profile record immediately after signup
    if (response.user != null) {
      try {
        await createProfile(
          userId: response.user!.id,
          fullName: fullName,
          role: role,
        );
      } catch (_) {
        // Profile may already exist via trigger — safe to ignore
      }
    }

    return response;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async => await client.auth.signOut();

  // ── Profile ───────────────────────────────────────────
  static Future<void> createProfile({
    required String userId,
    required String fullName,
    String role = 'employee',
  }) async {
    await client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'role': role,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    if (userId == null) return null;
    return await client.from('profiles').select().eq('id', userId!).single();
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    if (userId == null) return;
    await client.from('profiles').update({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId!);
  }

  // ── Attendance ────────────────────────────────────────
  static Future<Map<String, dynamic>?> getTodayAttendance() async {
    if (userId == null) return null;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await client
        .from('attendance')
        .select()
        .eq('user_id', userId!)
        .eq('date', today)
        .maybeSingle();
  }

  static Future<List<Map<String, dynamic>>> getAttendanceHistory() async {
    if (userId == null) return [];
    return await client
        .from('attendance')
        .select()
        .eq('user_id', userId!)
        .order('date', ascending: false)
        .limit(30);
  }

  static Future<void> checkIn({
    required double lat,
    required double lng,
    String? address,
    String? selfieUrl,
  }) async {
    await client.from('attendance').insert({
      'user_id': userId,
      'date': DateTime.now().toIso8601String().split('T')[0],
      'check_in_time': DateTime.now().toIso8601String(),
      'check_in_lat': lat,
      'check_in_lng': lng,
      'check_in_address': address,
      'check_in_selfie': selfieUrl,
      'status': 'present',
    });
  }

  static Future<void> checkOut({
    required String attendanceId,
    required double lat,
    required double lng,
    String? address,
    String? selfieUrl,
  }) async {
    await client.from('attendance').update({
      'check_out_time': DateTime.now().toIso8601String(),
      'check_out_lat': lat,
      'check_out_lng': lng,
      'check_out_address': address,
      'check_out_selfie': selfieUrl,
    }).eq('id', attendanceId);
  }

  // ── Location Tracking ─────────────────────────────────
  // NOTE: Throttling is handled inside the background isolate
  // in tracking_service.dart — do NOT add throttle here
  static Future<void> trackLocation({
    required double lat,
    required double lng,
    double? accuracy,
    double? speed,
    String? address,
    int? batteryLevel,
  }) async {
    await client.from('location_tracks').insert({
      'user_id': userId,
      'latitude': lat,
      'longitude': lng,
      'accuracy': accuracy,
      'speed': speed,
      'address': address,
      'battery_level': batteryLevel,
      'recorded_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Parties ───────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getParties() async {
    if (userId == null) return [];
    return await client
        .from('parties')
        .select()
        .eq('user_id', userId!)
        .eq('is_active', true)
        .order('name');
  }

  static Future<void> createParty(Map<String, dynamic> data) async {
    await client.from('parties').insert({
      ...data,
      'user_id': userId,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> updateParty(String id, Map<String, dynamic> data) async {
    await client.from('parties').update({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Visits ────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getVisits() async {
    if (userId == null) return [];
    return await client
        .from('visits')
        .select()
        .eq('user_id', userId!)
        .order('created_at', ascending: false);
  }

  static Future<Map<String, dynamic>?> getActiveVisit() async {
    if (userId == null) return null;
    return await client
        .from('visits')
        .select()
        .eq('user_id', userId!)
        .eq('status', 'active')
        .maybeSingle();
  }

  static Future<String> startVisit(Map<String, dynamic> data) async {
    final result = await client
        .from('visits')
        .insert({
          ...data,
          'user_id': userId,
          'check_in_time': DateTime.now().toIso8601String(),
          'status': 'active',
        })
        .select('id')
        .single();
    return result['id'];
  }

  static Future<void> endVisit(
      String visitId, Map<String, dynamic> data) async {
    await client.from('visits').update({
      ...data,
      'check_out_time': DateTime.now().toIso8601String(),
      'status': 'completed',
    }).eq('id', visitId);
  }

  static Future<void> createVisit(Map<String, dynamic> data) async {
    await client.from('visits').insert({
      ...data,
      'user_id': userId,
    });
  }

  // ── Leads (CRM) ───────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getLeads({String? status}) async {
    if (userId == null) return [];
    var query = client.from('leads').select().eq('user_id', userId!);
    if (status != null && status != 'all') {
      query = query.eq('status', status);
    }
    return await query.order('created_at', ascending: false);
  }

  static Future<void> createLead(Map<String, dynamic> data) async {
    await client.from('leads').insert({
      ...data,
      'user_id': userId,
    });
  }

  static Future<void> updateLead(String id, Map<String, dynamic> data) async {
    await client.from('leads').update({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Tasks ─────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getTasks({String? status}) async {
    if (userId == null) return [];
    var query = client
        .from('tasks')
        .select('*, assigner:profiles!assigned_by(full_name)')
        .eq('assigned_to', userId!);
    if (status != null && status != 'all') {
      query = query.eq('status', status);
    }
    return await query.order('created_at', ascending: false);
  }

  static Future<void> updateTaskStatus(String id, String status) async {
    final data = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (status == 'completed') {
      data['completed_at'] = DateTime.now().toIso8601String();
    }
    await client.from('tasks').update(data).eq('id', id);
  }

  // ── Expenses ──────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getExpenses() async {
    if (userId == null) return [];
    return await client
        .from('expenses')
        .select()
        .eq('user_id', userId!)
        .order('created_at', ascending: false);
  }

  static Future<void> createExpense(Map<String, dynamic> data) async {
    await client.from('expenses').insert({
      ...data,
      'user_id': userId,
      'expense_date': data['expense_date'] ??
          DateTime.now().toIso8601String().split('T')[0],
    });
  }

  // ── Notifications ─────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    if (userId == null) return [];
    return await client
        .from('notifications')
        .select()
        .eq('user_id', userId!)
        .order('created_at', ascending: false)
        .limit(50);
  }

  static Future<void> markNotificationRead(String id) async {
    await client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  // ── Dashboard Stats ───────────────────────────────────
  static Future<Map<String, dynamic>> getDashboardStats() async {
    if (userId == null) return {};
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayStart = '${today}T00:00:00.000';
    final todayEnd = '${today}T23:59:59.999';

    final results = await Future.wait([
      client
          .from('attendance')
          .select('id')
          .eq('user_id', userId!)
          .eq('date', today),
      client.from('leads').select('id').eq('user_id', userId!),
      client
          .from('tasks')
          .select('id')
          .eq('assigned_to', userId!)
          .eq('status', 'pending'),
      client
          .from('visits')
          .select('id')
          .eq('user_id', userId!)
          .gte('check_in_time', todayStart)
          .lte('check_in_time', todayEnd),
    ]);

    return {
      'is_checked_in': (results[0] as List).isNotEmpty,
      'total_leads': (results[1] as List).length,
      'pending_tasks': (results[2] as List).length,
      'today_visits': (results[3] as List).length,
    };
  }

  // ── Team ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getTeamMembers() async {
    return await client
        .from('profiles')
        .select()
        .eq('is_active', true)
        .order('full_name');
  }

  // ── Admin ─────────────────────────────────────────────
  static Future<bool> get isAdmin async {
    final profile = await getProfile();
    return profile?['role'] == 'admin';
  }

  static Future<bool> get isManager async {
    final profile = await getProfile();
    final role = profile?['role'];
    return role == 'admin' || role == 'manager';
  }

// All employees list for admin
  static Future<List<Map<String, dynamic>>> getAllEmployees() async {
    return await client
        .from('profiles')
        .select()
        .eq('is_active', true)
        .order('full_name');
  }

// Specific employee's attendance history
  static Future<List<Map<String, dynamic>>> getEmployeeAttendance(
      String employeeId) async {
    return await client
        .from('attendance')
        .select()
        .eq('user_id', employeeId)
        .order('date', ascending: false)
        .limit(30);
  }

// Specific employee's visits
  static Future<List<Map<String, dynamic>>> getEmployeeVisits(
      String employeeId) async {
    return await client
        .from('visits')
        .select()
        .eq('user_id', employeeId)
        .order('created_at', ascending: false);
  }

// Specific employee's location track (live)
  static Future<List<Map<String, dynamic>>> getEmployeeLiveLocation(
      String employeeId) async {
    return await client
        .from('location_tracks')
        .select()
        .eq('user_id', employeeId)
        .order('recorded_at', ascending: false)
        .limit(1);
  }

// All employees' last known location (admin map view)
  static Future<List<Map<String, dynamic>>> getAllEmployeeLocations() async {
    final data = await client
        .from('user_locations')
        .select('*, profiles!inner(full_name, role)')
        .neq('profiles.role', 'admin') // ✅ exclude admins
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

// Admin dashboard stats
  static Future<Map<String, dynamic>> getAdminDashboardStats() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final todayStart = '${today}T00:00:00.000';
      final todayEnd = '${today}T23:59:59.999';

      final results = await Future.wait<dynamic>([
        client.from('profiles').select('id, role').eq('is_active', true),
        client
            .from('attendance')
            .select('id')
            .eq('date', today)
            .eq('status', 'present'),
        client
            .from('visits')
            .select('id')
            .gte('check_in_time', todayStart)
            .lte('check_in_time', todayEnd),
        client.from('expenses').select('id').eq('status', 'pending'),
        client.from('leads').select('id'),
      ]);

      final allProfiles = results[0] as List;
      final nonAdmins = allProfiles.where((e) => e['role'] != 'admin').toList();

      return {
        'total_employees': nonAdmins.length,
        'checked_in_today': (results[1] as List).length,
        'total_visits_today': (results[2] as List).length,
        'pending_expenses': (results[3] as List).length,
        'total_leads': (results[4] as List).length,
        'active_trackers': 0,
      };
    } catch (e) {
      print('Dashboard stats error: $e');
      return {
        'total_employees': 0,
        'checked_in_today': 0,
        'total_visits_today': 0,
        'pending_expenses': 0,
        'total_leads': 0,
        'active_trackers': 0,
      };
    }
  }

// Approve or reject expense
  static Future<void> updateExpenseStatus(
      String expenseId, String status) async {
    await client.from('expenses').update({
      'status': status,
      'approved_by': userId,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', expenseId);
  }

// Assign task to employee
  static Future<void> createTask(Map<String, dynamic> data) async {
    await client.from('tasks').insert({
      ...data,
      'assigned_by': userId,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
  }

// Toggle employee active status
  static Future<void> toggleEmployeeStatus(
      String employeeId, bool isActive) async {
    await client.from('profiles').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', employeeId);
  }
}
