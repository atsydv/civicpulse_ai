import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../widgets/loading_skeleton_widget.dart';
import '../../../widgets/severity_badge_widget.dart';

class AiResultCardWidget extends StatefulWidget {
  final bool isLoading;
  final Map<String, dynamic>? result;

  const AiResultCardWidget({
    super.key,
    required this.isLoading,
    required this.result,
  });

  @override
  State<AiResultCardWidget> createState() => _AiResultCardWidgetState();
}

class _AiResultCardWidgetState extends State<AiResultCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    if (!widget.isLoading && widget.result != null) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AiResultCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLoading && widget.result != null) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isLoading
                  ? Colors.white.withAlpha(20)
                  : AppTheme.primary.withAlpha(64),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: widget.isLoading ? _buildSkeleton() : _buildResult(),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const LoadingSkeletonWidget(width: 32, height: 32, borderRadius: 8),
            const SizedBox(width: 10),
            const Expanded(
              child: LoadingSkeletonWidget(height: 16, borderRadius: 8),
            ),
            const SizedBox(width: 10),
            const LoadingSkeletonWidget(
              width: 70,
              height: 24,
              borderRadius: 12,
            ),
          ],
        ),
        const SizedBox(height: 14),
        const LoadingSkeletonWidget(height: 13, borderRadius: 6),
        const SizedBox(height: 6),
        const LoadingSkeletonWidget(width: 200, height: 13, borderRadius: 6),
      ],
    );
  }

  Widget _buildResult() {
    if (widget.result == null) return const SizedBox.shrink();

    final result = widget.result!;
    final severity = result['severity'] as String? ?? 'Medium';
    final category = result['category'] as String? ?? 'Road Hazard';
    // Support both 'description' (new) and 'reason' (legacy) fields
    final description =
        result['description'] as String? ??
        result['reason'] as String? ??
        'Civic hazard detected at the reported location.';
    final hazardReason =
        result['hazard_reason'] as String? ??
        'This hazard poses a risk to citizens in the area.';
    final confidenceRaw = result['confidence'];
    double confidenceDouble;
    if (confidenceRaw is int) {
      confidenceDouble = confidenceRaw / 100.0;
    } else if (confidenceRaw is double) {
      confidenceDouble = confidenceRaw > 1.0
          ? confidenceRaw / 100.0
          : confidenceRaw;
    } else {
      confidenceDouble = 0.75;
    }
    final confidence = confidenceDouble * 100;

    String categoryIcon;
    switch (category.toLowerCase()) {
      case 'pothole':
        categoryIcon = 'report_problem';
        break;
      case 'broken streetlight':
        categoryIcon = 'lightbulb_outline';
        break;
      case 'waterlogging':
        categoryIcon = 'water';
        break;
      case 'exposed wires':
        categoryIcon = 'electrical_services';
        break;
      case 'garbage overflow':
        categoryIcon = 'delete_outline';
        break;
      case 'fallen tree':
        categoryIcon = 'park';
        break;
      case 'road hazard':
        categoryIcon = 'warning_amber_rounded';
        break;
      default:
        categoryIcon = 'warning_amber_rounded';
    }

    Color severityColor;
    switch (severity.toLowerCase()) {
      case 'critical':
        severityColor = const Color(0xFFEF4444);
        break;
      case 'high':
        severityColor = const Color(0xFFF97316);
        break;
      case 'medium':
        severityColor = const Color(0xFFEAB308);
        break;
      case 'low':
        severityColor = const Color(0xFF22C55E);
        break;
      default:
        severityColor = const Color(0xFFEAB308);
    }

    return FadeTransition(
      opacity: _fadeIn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(38),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: CustomIconWidget(
                    iconName: 'auto_awesome',
                    color: AppTheme.primary,
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
                      'Gemini AI Triage Result',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${confidence.toStringAsFixed(0)}% confidence',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SeverityBadgeWidget(severity: severity),
            ],
          ),

          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withAlpha(15)),
          const SizedBox(height: 16),

          // Category
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: severityColor.withAlpha(38),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: CustomIconWidget(
                    iconName: categoryIcon,
                    color: severityColor,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hazard Category',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    category,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Description
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(15), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CustomIconWidget(
                  iconName: 'info_outline',
                  color: Color(0xFF94A3B8),
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFFCBD5E1),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Hazard Reason
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: severityColor.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: severityColor.withAlpha(40), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomIconWidget(
                  iconName: 'warning_amber_rounded',
                  color: severityColor,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hazardReason,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFFCBD5E1),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
