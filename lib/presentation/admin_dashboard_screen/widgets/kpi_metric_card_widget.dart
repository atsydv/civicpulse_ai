import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/app_export.dart';

class KpiMetricCardWidget extends StatelessWidget {
  final Map<String, dynamic> kpi;

  const KpiMetricCardWidget({super.key, required this.kpi});

  @override
  Widget build(BuildContext context) {
    final color = kpi['color'] as Color;
    final value = kpi['value'] as int;
    final label = kpi['label'] as String;
    final icon = kpi['icon'] as String;
    final delta = kpi['delta'] as String;
    final deltaPositive = kpi['deltaPositive'] as bool;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withAlpha(51), width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: icon + label
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withAlpha(38),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: CustomIconWidget(
                        iconName: icon,
                        color: color,
                        size: 16,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (deltaPositive ? AppTheme.success : AppTheme.error)
                          .withAlpha(31),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName: deltaPositive
                              ? 'arrow_upward'
                              : 'arrow_downward',
                          color: deltaPositive
                              ? AppTheme.success
                              : AppTheme.error,
                          size: 9,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          delta.split(' ').first,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: deltaPositive
                                ? AppTheme.success
                                : AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Value
              Text(
                '$value',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              // Label
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Delta detail
              Text(
                delta,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: color.withAlpha(179),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
