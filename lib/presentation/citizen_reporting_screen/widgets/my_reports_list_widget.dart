import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../core/services/app_data_service.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/severity_badge_widget.dart';
import '../../../widgets/status_badge_widget.dart';
import './report_progress_widget.dart';

class MyReportsListWidget extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? currentUser;

  const MyReportsListWidget({
    super.key,
    required this.userId,
    this.currentUser,
  });

  @override
  State<MyReportsListWidget> createState() => _MyReportsListWidgetState();
}

class _MyReportsListWidgetState extends State<MyReportsListWidget> {
  late List<Map<String, dynamic>> _reports;
  final Set<String> _expandedProgress = {};
  final Set<String> _feedbackSubmitted = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  void _loadReports() {
    setState(() {
      _reports = AppDataService.instance.getTicketsByUser(widget.userId);
    });
  }

  String _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'pothole':
        return 'report_problem';
      case 'broken streetlight':
        return 'lightbulb_outline';
      case 'waterlogging':
        return 'water';
      case 'exposed wires':
        return 'electrical_services';
      case 'garbage overflow':
        return 'delete_outline';
      default:
        return 'warning_amber_rounded';
    }
  }

  void _showFeedbackDialog(Map<String, dynamic> report) {
    int rating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.success.withAlpha(38),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: CustomIconWidget(
                    iconName: 'rate_review',
                    color: AppTheme.success,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rate Resolution',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How satisfied are you with the resolution of ${report['category']}?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Star rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return GestureDetector(
                    onTap: () => setDialogState(() => rating = starIndex),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: CustomIconWidget(
                        iconName: starIndex <= rating ? 'star' : 'star_border',
                        color: starIndex <= rating
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF64748B),
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Share your experience (optional)...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF475569),
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white.withAlpha(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withAlpha(30),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withAlpha(30),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.success,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: rating == 0
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _feedbackSubmitted.add(report['id'] as String);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Thank you for your feedback! ⭐ $rating/5',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: AppTheme.success,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                disabledBackgroundColor: Colors.white.withAlpha(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: Text(
                'Submit',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_reports.isEmpty) {
      return const EmptyStateWidget(
        iconName: 'receipt_long',
        title: 'No reports yet',
        subtitle:
            'Tap the camera button below to capture your first civic hazard. Your submissions help improve the city.',
        ctaLabel: 'Report a Hazard',
      );
    }

    final totalReports = _reports.length;
    final resolvedReports = _reports
        .where((r) => r['status'] == 'CLOSED')
        .length;
    final inProgressReports = _reports
        .where((r) => r['status'] == 'IN_PROGRESS')
        .length;

    return RefreshIndicator(
      onRefresh: () async => _loadReports(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.surfaceDark,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: _reports.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildStatsRow(
              total: totalReports,
              resolved: resolvedReports,
              inProgress: inProgressReports,
            );
          }
          final report = _reports[index - 1];
          return _buildReportCard(report, index - 1);
        },
      ),
    );
  }

  Widget _buildStatsRow({
    required int total,
    required int resolved,
    required int inProgress,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              label: 'Total',
              value: total,
              iconName: 'receipt_long',
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              label: 'In Progress',
              value: inProgress,
              iconName: 'engineering',
              color: AppTheme.high,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              label: 'Resolved',
              value: resolved,
              iconName: 'check_circle_outline',
              color: AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required int value,
    required String iconName,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomIconWidget(iconName: iconName, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, int index) {
    final ticketId = report['id'] as String? ?? '';
    final isExpanded = _expandedProgress.contains(ticketId);
    final isResolved = report['status'] == 'CLOSED';
    final hasFeedback = _feedbackSubmitted.contains(ticketId);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 16),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isResolved
                      ? AppTheme.success.withAlpha(38)
                      : Colors.white.withAlpha(20),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.severityColor(
                            report['severity'] as String? ?? 'MEDIUM',
                          ).withAlpha(38),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: CustomIconWidget(
                            iconName: _categoryIcon(
                              report['category'] as String? ?? '',
                            ),
                            color: AppTheme.severityColor(
                              report['severity'] as String? ?? 'MEDIUM',
                            ),
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report['category'] as String? ?? 'Hazard',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              ticketId,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SeverityBadgeWidget(
                        severity: report['severity'] as String? ?? 'MEDIUM',
                        showGlow: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: Colors.white.withAlpha(13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const CustomIconWidget(
                        iconName: 'place_outlined',
                        color: Color(0xFF64748B),
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          report['address'] as String? ?? 'Prayagraj',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StatusBadgeWidget(
                        status: report['status'] as String? ?? 'TRIAGED',
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CustomIconWidget(
                              iconName: 'thumb_up_outlined',
                              color: Color(0xFF64748B),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${report['upvotes'] ?? 0}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (report['assignedTo'] != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              const CustomIconWidget(
                                iconName: 'engineering',
                                color: Color(0xFF64748B),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  report['assignedTo'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Progress toggle button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedProgress.remove(ticketId);
                            } else {
                              _expandedProgress.add(ticketId);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primary.withAlpha(50),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CustomIconWidget(
                                iconName: 'timeline',
                                color: AppTheme.primary,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isExpanded ? 'Hide' : 'Progress',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              CustomIconWidget(
                                iconName: isExpanded
                                    ? 'keyboard_arrow_up'
                                    : 'keyboard_arrow_down',
                                color: AppTheme.primary,
                                size: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Progress tracker (expandable)
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    ReportProgressWidget(ticket: report),
                  ],
                  // Feedback button for resolved reports
                  if (isResolved) ...[
                    const SizedBox(height: 12),
                    Container(height: 1, color: Colors.white.withAlpha(13)),
                    const SizedBox(height: 12),
                    hasFeedback
                        ? Row(
                            children: [
                              const CustomIconWidget(
                                iconName: 'check_circle',
                                color: AppTheme.success,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Feedback submitted — thank you!',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : GestureDetector(
                            onTap: () => _showFeedbackDialog(report),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.success.withAlpha(60),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CustomIconWidget(
                                    iconName: 'rate_review',
                                    color: AppTheme.success,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Rate Resolution',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
