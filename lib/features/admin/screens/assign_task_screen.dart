import 'package:flutter/material.dart';
import 'package:vartmaan_pulse/core/services/supabase_service.dart';
import 'admin_shell.dart';

class AssignTaskScreen extends StatefulWidget {
  const AssignTaskScreen({super.key});
  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<Map<String, dynamic>> _employees = [];
  String? _selectedEmployeeId;
  DateTime? _dueDate;
  String _priority = 'medium';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final data = await SupabaseService.getAllEmployees();
    setState(() => _employees = data);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill all fields and select an employee')));
      return;
    }
    setState(() => _loading = true);
    await SupabaseService.createTask({
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'assigned_to': _selectedEmployeeId,
      'priority': _priority,
      'due_date': _dueDate?.toIso8601String(),
    });
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Task assigned successfully'),
          backgroundColor: Colors.green));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Task'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Assign To *'),
              DropdownButtonFormField<String>(
                value: _selectedEmployeeId,
                decoration: _inputDecoration('Select employee'),
                items: _employees
                    .map((e) => DropdownMenuItem(
                          value: e['id'] as String,
                          child: Text(e['full_name'] ?? ''),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedEmployeeId = v),
                validator: (v) => v == null ? 'Select an employee' : null,
              ),
              const SizedBox(height: 16),
              _label('Task Title *'),
              TextFormField(
                controller: _titleCtrl,
                decoration: _inputDecoration('e.g. Visit client at ABC Corp'),
                validator: (v) => v!.isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 16),
              _label('Description'),
              TextFormField(
                controller: _descCtrl,
                decoration: _inputDecoration('Task details...'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _label('Priority'),
              Row(
                children: ['low', 'medium', 'high'].map((p) {
                  final colors = {
                    'low': Colors.green,
                    'medium': Colors.orange,
                    'high': Colors.red,
                  };
                  final isSelected = _priority == p;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors[p]!.withOpacity(0.15)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? colors[p]!
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              p[0].toUpperCase() + p.substring(1),
                              style: TextStyle(
                                color: isSelected ? colors[p] : Colors.grey,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _label('Due Date'),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setState(() => _dueDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.grey, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        _dueDate != null
                            ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                            : 'Select due date (optional)',
                        style: TextStyle(
                            color: _dueDate != null
                                ? Colors.black87
                                : Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Assign Task',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
      );
}


