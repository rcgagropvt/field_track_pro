import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/custom_button.dart';

class TaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Map<String, dynamic> _task;

  @override
  void initState() {
    super.initState();
    _task = Map.from(widget.task);
  }

  Future<void> _updateStatus(String status) async {
    await SupabaseService.updateTaskStatus(_task['id'], status);
    setState(() => _task['status'] = status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _task['title'] ?? '',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (_task['description'] != null)
              Text(
                _task['description'],
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

            const SizedBox(height: 24),

            // Info rows
            _infoCard([
              _infoRow('Status', _task['status']?.toString().toUpperCase() ?? 'PENDING'),
              _infoRow('Priority', _task['priority']?.toString().toUpperCase() ?? 'MEDIUM'),
              if (_task['due_date'] != null)
                _infoRow('Due Date', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_task['due_date']))),
              if (_task['assigner'] != null)
                _infoRow('Assigned By', _task['assigner']['full_name'] ?? 'Unknown'),
              if (_task['target_address'] != null)
                _infoRow('Location', _task['target_address']),
            ]),

            const SizedBox(height: 32),

            if (_task['status'] != 'completed') ...[
              if (_task['status'] == 'pending')
                CustomButton(
                  text: 'Start Task',
                  onPressed: () => _updateStatus('in_progress'),
                  icon: Icons.play_arrow_rounded,
                ),
              if (_task['status'] == 'in_progress') ...[
                CustomButton(
                  text: 'Mark Complete',
                  onPressed: () => _updateStatus('completed'),
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
              ],
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: 8),
                    Text(
                      'Task Completed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
