import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/services/supabase_service.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _priority = 'medium';
  DateTime? _dueDate;
  bool _isLoading = false;

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 17, minute: 0),
      );

      setState(() {
        if (time != null) {
          _dueDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await SupabaseService.client.from('tasks').insert({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'priority': _priority,
        'status': 'pending',
        'assigned_to': SupabaseService.userId,
        'assigned_by': SupabaseService.userId,
        'due_date': _dueDate?.toIso8601String(),
        'target_address': _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task created successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Task'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                controller: _titleCtrl,
                label: 'Task Title *',
                prefixIcon: Icons.title_rounded,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              CustomTextField(
                controller: _descCtrl,
                label: 'Description',
                prefixIcon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 14),

              // Priority
              const Text('Priority',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: ['low', 'medium', 'high', 'urgent'].map((p) {
                  final selected = _priority == p;
                  final color = _getPriorityColor(p);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = p),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? color : color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? color : color.withOpacity(0.3),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            p.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected ? AppColors.white : color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // Due Date
              GestureDetector(
                onTap: _pickDueDate,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _dueDate != null
                              ? 'Due: ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year} at ${_dueDate!.hour}:${_dueDate!.minute.toString().padLeft(2, '0')}'
                              : 'Tap to set due date & time',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _dueDate != null
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                      if (_dueDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _dueDate = null),
                          child: const Icon(Icons.clear, size: 18,
                              color: AppColors.textTertiary),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              CustomTextField(
                controller: _addressCtrl,
                label: 'Location (optional)',
                prefixIcon: Icons.location_on_outlined,
              ),

              const SizedBox(height: 32),

              CustomButton(
                text: 'Create Task',
                onPressed: _save,
                isLoading: _isLoading,
                icon: Icons.add_task_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String p) {
    switch (p) {
      case 'urgent': return AppColors.error;
      case 'high': return AppColors.warning;
      case 'medium': return AppColors.info;
      case 'low': return AppColors.success;
      default: return AppColors.textTertiary;
    }
  }
}
