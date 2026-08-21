import 'package:flutter/material.dart';

import '../../../core/app_export.dart';

class KarmaHeaderWidget extends StatelessWidget {
  final int karma;

  const KarmaHeaderWidget({super.key, required this.karma});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.medium.withAlpha(38), AppTheme.high.withAlpha(38)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.medium.withAlpha(77), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomIconWidget(iconName: 'bolt', color: AppTheme.medium, size: 14),
          const SizedBox(width: 4),
          Text(
            '$karma',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.medium,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'pts',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.medium.withAlpha(179),
            ),
          ),
        ],
      ),
    );
  }
}
