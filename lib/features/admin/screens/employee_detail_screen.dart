import 'package:flutter/material.dart';
import 'package:field_track_pro/core/services/supabase_service.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> employee;
  const EmployeeDetailScreen({super.key, required this.employee});
  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen>
    with DefaultTabControllerMixin {
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _visits = [];
  List<Map<String, dynamic>> _leads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.employee['id'];
    final results = await Future.wait([
      SupabaseService.getEmployeeAttendance(id),
      SupabaseService.getEmployeeVisits(id),
      SupabaseService.client
          .from('leads')
          .select()
          .eq('user_id', id)
          .order('created_at', ascending: false)
          .limit(20),
    ]);
    setState(() {
      _attendance = List<Map<String, dynamic>>.from(results[0]);
      _visits = List<Map<String, dynamic>>.from(results[1]);
      _leads = List<Map<String, dynamic>>.from(results[2]);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(e['full_name'] ?? 'Employee Detail'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: 'Attendance'),
              Tab(text: 'Visits'),
              Tab(text: 'Leads'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildProfileHeader(e),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildAttendanceTab(),
                        _buildVisitsTab(),
                        _buildLeadsTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> e) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.blue.shade100,
            backgroundImage:
                e['avatar_url'] != null ? NetworkImage(e['avatar_url']) : null,
            child: e['avatar_url'] == null
                ? Text((e['full_name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e['full_name'] ?? '',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(e['email'] ?? '',
                    style: const TextStyle(color: Colors.grey)),
                if (e['phone'] != null)
                  Text(e['phone'], style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Row(children: [
                  _buildChip(e['role'] ?? 'employee', Colors.blue),
                  const SizedBox(width: 8),
                  _buildChip((e['is_active'] ?? true) ? 'Active' : 'Inactive',
                      (e['is_active'] ?? true) ? Colors.green : Colors.red),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildAttendanceTab() {
    if (_attendance.isEmpty) {
      return const Center(child: Text('No attendance records'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _attendance.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) {
        final a = _attendance[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: a['check_in'] != null
                ? Colors.green.shade50
                : Colors.red.shade50,
            child: Icon(
              a['check_in'] != null ? Icons.check : Icons.close,
              color: a['check_in'] != null ? Colors.green : Colors.red,
              size: 18,
            ),
          ),
          title: Text(a['date'] ?? ''),
          subtitle: Text(
              'In: ${a['check_in'] ?? '--'}  Out: ${a['check_out'] ?? '--'}'),
          trailing: a['total_hours'] != null
              ? Text('${a['total_hours']}h',
                  style: const TextStyle(fontWeight: FontWeight.bold))
              : null,
        );
      },
    );
  }

  Widget _buildVisitsTab() {
    if (_visits.isEmpty) {
      return const Center(child: Text('No visits recorded'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _visits.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) {
        final v = _visits[i];
        return ListTile(
          leading: const Icon(Icons.place, color: Colors.orange),
          title: Text(v['customer_name'] ?? 'Customer'),
          subtitle: Text(v['purpose'] ?? ''),
          trailing: Text(
              v['check_in_time'] != null
                  ? v['check_in_time'].toString().substring(0, 10)
                  : '',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        );
      },
    );
  }

  Widget _buildLeadsTab() {
    if (_leads.isEmpty) {
      return const Center(child: Text('No leads found'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _leads.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) {
        final l = _leads[i];
        final statusColor = l['status'] == 'converted'
            ? Colors.green
            : l['status'] == 'lost'
                ? Colors.red
                : Colors.orange;
        return ListTile(
          leading: const Icon(Icons.person_add, color: Colors.purple),
          title: Text(l['name'] ?? ''),
          subtitle: Text(l['company'] ?? ''),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(l['status'] ?? '',
                style: TextStyle(color: statusColor, fontSize: 12)),
          ),
        );
      },
    );
  }
}

mixin DefaultTabControllerMixin<T extends StatefulWidget> on State<T> {}
