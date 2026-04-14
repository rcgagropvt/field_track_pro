import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getNotifications();
      if (mounted) setState(() { _notifications = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    for (final n in _notifications.where((n) => n['is_read'] != true)) {
      await SupabaseService.markNotificationRead(n['id']);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No Notifications',
                  subtitle: 'You\'re all caught up!',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isUnread = n['is_read'] != true;
                      final time = n['created_at'] != null
                          ? DateFormat('dd MMM, hh:mm a')
                              .format(DateTime.parse(n['created_at']))
                          : '';
                      return GestureDetector(
                        onTap: () async {
                          if (isUnread) {
                            await SupabaseService.markNotificationRead(n['id']);
                            _load();
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isUnread
                                ? AppColors.primarySurface
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isUnread
                                  ? AppColors.primary.withOpacity(0.3)
                                  : AppColors.divider,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.notifications_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n['title'] ?? 'Notification',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isUnread
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (n['body'] != null) ...[
                                      const SizedBox(height: 2),
                                      Text(n['body'],
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary)),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(time,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textTertiary)),
                                  ],
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}