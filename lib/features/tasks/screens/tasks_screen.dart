import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../router/app_router.dart';
import 'add_task_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      var query = SupabaseService.client
          .from('tasks')
          .select('*, assigner:assigned_by(full_name)');

      // Show tasks assigned TO me or BY me
      final uid = SupabaseService.userId;
      if (uid != null) {
        query = query.or('assigned_to.eq.$uid,assigned_by.eq.$uid');
      }

      if (_filter != 'all') {
        query = query.eq('status', _filter);
      }

      final data = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.info;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (v) {
              setState(() => _filter = v);
              _loadTasks();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('ALL')),
              const PopupMenuItem(value: 'pending', child: Text('PENDING')),
              const PopupMenuItem(
                  value: 'in_progress', child: Text('IN PROGRESS')),
              const PopupMenuItem(value: 'completed', child: Text('COMPLETED')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTaskScreen()),
          );
          _loadTasks();
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _tasks.isEmpty
              ? EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'No Tasks Yet',
                  subtitle: 'Create a task for yourself or your team',
                  buttonText: 'Create Task',
                  onButtonPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
                    );
                    _loadTasks();
                  },
                )
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return _TaskCard(
                        task: task,
                        priorityColor:
                            _priorityColor(task['priority'] ?? 'medium'),
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            AppRouter.taskDetail,
                            arguments: task,
                          );
                          _loadTasks();
                        },
                        onStatusChange: (status) async {
                          await SupabaseService.updateTaskStatus(
                              task['id'], status);
                          _loadTasks();
                        },
                      )
                          .animate(delay: Duration(milliseconds: index * 60))
                          .fadeIn(duration: 300.ms)
                          .slideX(begin: 0.05);
                    },
                  ),
                ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final Color priorityColor;
  final VoidCallback onTap;
  final Function(String) onStatusChange;

  const _TaskCard({
    required this.task,
    required this.priorityColor,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final dueDate = task['due_date'] != null
        ? DateFormat('dd MMM').format(DateTime.parse(task['due_date']))
        : null;
    final isCompleted = task['status'] == 'completed';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () =>
                  onStatusChange(isCompleted ? 'pending' : 'completed'),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.success : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color:
                          isCompleted ? AppColors.success : AppColors.divider,
                      width: 2),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 16, color: AppColors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (task['description'] != null) ...[
                    const SizedBox(height: 4),
                    Text(task['description'],
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StatusBadge(status: task['status'] ?? 'pending'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (task['priority'] ?? 'medium')
                              .toString()
                              .toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: priorityColor),
                        ),
                      ),
                      if (dueDate != null) ...[
                        const Spacer(),
                        Icon(Icons.schedule_rounded,
                            size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(dueDate,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textTertiary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}


