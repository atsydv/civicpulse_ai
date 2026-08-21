import 'package:flutter/material.dart';

import '../../../core/app_export.dart';

class ReportProgressWidget extends StatelessWidget {
  final Map<String, dynamic> ticket;

  const ReportProgressWidget({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] as String? ?? 'TRIAGED';
    final viewedAt = ticket['viewedAt'] as String?;
    final assignedTo = ticket['assignedTo'] as String?;
    final resolvedAt = ticket['resolvedAt'] as String?;

    // Determine current step (0-indexed)
    int currentStep = 0;
    if (status == 'TRIAGED' && viewedAt != null) {
      currentStep = 1;
    } else if (status == 'IN_PROGRESS' || assignedTo != null) {
      currentStep = 2;
    } else if (status == 'CLOSED') {
      currentStep = 3;
    }

    final steps = [
      _ProgressStep(
        icon: 'upload_file',
        label: 'Report Submitted',
        sublabel: _formatDate(ticket['timestamp'] as String?),
        isCompleted: true,
        isActive: currentStep == 0,
        color: AppTheme.primary,
      ),
      _ProgressStep(
        icon: 'visibility',
        label: 'Report Viewed',
        sublabel: viewedAt != null ? _formatDate(viewedAt) : 'Pending review',
        isCompleted: currentStep >= 1,
        isActive: currentStep == 1,
        color: AppTheme.secondary,
      ),
      _ProgressStep(
        icon: 'engineering',
        label: 'Worker Assigned',
        sublabel: assignedTo ?? 'Awaiting dispatch',
        isCompleted: currentStep >= 2,
        isActive: currentStep == 2,
        color: AppTheme.high,
      ),
      _ProgressStep(
        icon: 'check_circle',
        label: 'Problem Resolved',
        sublabel: resolvedAt != null ? _formatDate(resolvedAt) : 'In progress',
        isCompleted: currentStep >= 3,
        isActive: currentStep == 3,
        color: AppTheme.success,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CustomIconWidget(
                iconName: 'timeline',
                color: AppTheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Report Progress',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == steps.length - 1;
            return _buildStepRow(step, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildStepRow(_ProgressStep step, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon + connector line
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: step.isCompleted
                    ? step.color
                    : step.isActive
                    ? step.color.withAlpha(50)
                    : Colors.white.withAlpha(15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: step.isCompleted
                      ? step.color
                      : step.isActive
                      ? step.color.withAlpha(100)
                      : Colors.white.withAlpha(30),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: CustomIconWidget(
                  iconName: step.icon,
                  color: step.isCompleted
                      ? Colors.white
                      : step.isActive
                      ? step.color
                      : const Color(0xFF64748B),
                  size: 15,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: step.isCompleted
                    ? step.color.withAlpha(100)
                    : Colors.white.withAlpha(20),
              ),
          ],
        ),
        const SizedBox(width: 12),
        // Text
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  step.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: step.isCompleted || step.isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: step.isCompleted || step.isActive
                        ? Colors.white
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.sublabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: step.isCompleted
                        ? step.color
                        : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        if (step.isCompleted)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CustomIconWidget(
              iconName: 'check_circle',
              color: step.color,
              size: 14,
            ),
          ),
      ],
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _ProgressStep {
  final String icon;
  final String label;
  final String sublabel;
  final bool isCompleted;
  final bool isActive;
  final Color color;

  const _ProgressStep({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isCompleted,
    required this.isActive,
    required this.color,
  });
}
