import 'package:flutter/material.dart';
import 'package:vartmaan_pulse/core/services/supabase_service.dart';
import 'employee_detail_screen.dart';
import 'admin_shell.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});
  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await SupabaseService.getAllEmployees();
    setState(() {
      _employees = data;
      _filtered = data;
      _loading = false;
    });
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _employees
          .where((e) =>
              (e['full_name'] ?? '').toLowerCase().contains(q) ||
              (e['email'] ?? '').toLowerCase().contains(q) ||
              (e['department'] ?? '').toLowerCase().contains(q))
          .toList();
    });
  }

  Future<void> _toggleStatus(String id, bool current) async {
    await SupabaseService.toggleEmployeeStatus(id, !current);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Employees'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, email, department...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final e = _filtered[i];
                        final isActive = e['is_active'] ?? true;
                        return ListTile(
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage: e['avatar_url'] != null
                                ? NetworkImage(e['avatar_url'])
                                : null,
                            child: e['avatar_url'] == null
                                ? Text((e['full_name'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))
                                : null,
                          ),
                          title: Text(e['full_name'] ?? 'Unknown',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e['email'] ?? ''),
                              if (e['department'] != null)
                                Text(e['department'],
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isActive ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                            ],
                          ),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      EmployeeDetailScreen(employee: e))),
                          onLongPress: () => _showStatusDialog(
                              e['id'], isActive, e['full_name'] ?? 'employee'),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showStatusDialog(String id, bool isActive, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${isActive ? 'Deactivate' : 'Activate'} $name?'),
        content: Text(isActive
            ? 'This will prevent them from logging in.'
            : 'This will restore their access.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleStatus(id, isActive);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.red : Colors.green),
            child: Text(isActive ? 'Deactivate' : 'Activate',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}


