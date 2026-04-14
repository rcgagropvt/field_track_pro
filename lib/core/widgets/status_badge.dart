import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final Map<String, Color>? colorMap;

  const StatusBadge({
    super.key,
    required this.status,
    this.colorMap,
  });

  Color _getColor() {
    if (colorMap != null && colorMap!.containsKey(status)) {
      return colorMap![status]!;
    }

    switch (status.toLowerCase()) {
      case 'present':
      case 'completed':
      case 'approved':
      case 'won':
      case 'active':
        return AppColors.success;
      case 'pending':
      case 'new':
      case 'planned':
        return AppColors.info;
      case 'in_progress':
      case 'contacted':
      case 'qualified':
      case 'proposal':
        return AppColors.warning;
      case 'absent':
      case 'cancelled':
      case 'rejected':
      case 'lost':
      case 'overdue':
        return AppColors.error;
      case 'late':
      case 'half_day':
      case 'negotiation':
        return AppColors.warningLight.withOpacity(1);
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final displayText = status.replaceAll('_', ' ').toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
