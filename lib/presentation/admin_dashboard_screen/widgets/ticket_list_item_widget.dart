import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../widgets/severity_badge_widget.dart';
import '../../../widgets/status_badge_widget.dart';

class TicketListItemWidget extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final int index;
  final void Function(String ticketId, String workerName) onAssignWorker;

  const TicketListItemWidget({
    super.key,
    required this.ticket,
    required this.index,
    required this.onAssignWorker,
  });

  @override
  State<TicketListItemWidget> createState() => _TicketListItemWidgetState();
}

class _TicketListItemWidgetState extends State<TicketListItemWidget> {
  bool _isExpanded = false;
  String? _selectedWorker;

  static const List<String> _availableWorkers = [
    'Field Crew Dave',
    'Field Crew Maria',
    'Field Crew Singh',
    'Field Crew Tanaka',
    'Field Crew Chen',
    'Field Crew Okafor',
  ];

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final severity = ticket['severity'] as String;
    final status = ticket['status'] as String;
    final severityColor = AppTheme.severityColor(severity);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + widget.index * 50),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: child,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(13),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: severity == 'CRITICAL'
                    ? AppTheme.critical.withAlpha(64)
                    : Colors.white.withAlpha(20),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Main card content
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  borderRadius: BorderRadius.circular(20),
                  splashColor: severityColor.withAlpha(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: image thumbnail + title block + severity
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Before image thumbnail — supports both imageUrl and imageBase64
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _buildThumbnail(ticket),
                            ),
                            const SizedBox(width: 12),
                            // Title + category + id
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ticket['category'] as String,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SeverityBadgeWidget(
                                        severity: severity,
                                        showGlow: severity == 'CRITICAL',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    ticket['id'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const CustomIconWidget(
                                        iconName: 'place_outlined',
                                        color: Color(0xFF64748B),
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          ticket['address'] as String,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Row 2: status + upvotes + timestamp + reporter
                        Row(
                          children: [
                            StatusBadgeWidget(status: status),
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
                                    size: 11,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${ticket['upvotes']}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatTimestamp(ticket['timestamp'] as String),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),

                        // GPS coords row
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const CustomIconWidget(
                              iconName: 'gps_fixed',
                              color: Color(0xFF64748B),
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatCoords(
                                ticket['latitude'],
                                ticket['longitude'],
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: const Color(0xFF64748B),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const CustomIconWidget(
                              iconName: 'person_outline',
                              color: Color(0xFF64748B),
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ticket['reporter'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const Spacer(),
                            // Expand toggle
                            CustomIconWidget(
                              iconName: _isExpanded
                                  ? 'keyboard_arrow_up'
                                  : 'keyboard_arrow_down',
                              color: const Color(0xFF64748B),
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Expanded dispatch section
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: _isExpanded
                      ? _buildDispatchSection(ticket)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDispatchSection(Map<String, dynamic> ticket) {
    final status = ticket['status'] as String;
    final assignedTo = ticket['assignedTo'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(15), width: 1),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI reason
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
                  iconName: 'auto_awesome',
                  color: AppTheme.primary,
                  size: 13,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ticket['aiReason'] as String? ??
                        ticket['description'] as String? ??
                        'AI analysis completed.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFFCBD5E1),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Dispatch row
          if (status != 'CLOSED')
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withAlpha(26),
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedWorker ?? assignedTo,
                        hint: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            assignedTo ?? 'Assign crew...',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: assignedTo != null
                                  ? AppTheme.secondary
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        icon: const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: CustomIconWidget(
                            iconName: 'expand_more',
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                        ),
                        items: _availableWorkers.map((worker) {
                          return DropdownMenuItem<String>(
                            value: worker,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                worker,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedWorker = val),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Dispatch button
                GestureDetector(
                  onTap: () {
                    final worker = _selectedWorker ?? assignedTo;
                    if (worker != null) {
                      widget.onAssignWorker(ticket['id'] as String, worker);
                      setState(() => _isExpanded = false);
                    }
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withAlpha(77),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CustomIconWidget(
                          iconName: 'send_rounded',
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Dispatch',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.success.withAlpha(31),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.success.withAlpha(77),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const CustomIconWidget(
                    iconName: 'verified',
                    color: AppTheme.success,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Repair verified and closed by ${assignedTo ?? 'field crew'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a 56×56 thumbnail that works for both network-URL tickets
  /// (default data) and citizen-submitted tickets that store a base64 image.
  Widget _buildThumbnail(Map<String, dynamic> ticket) {
    final imageUrl = ticket['imageUrl'] as String?;
    final imageBase64 = ticket['imageBase64'] as String?;

    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(imageBase64),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          semanticLabel: 'Citizen submitted hazard photo',
          errorBuilder: (_, __, ___) => _thumbnailPlaceholder(ticket),
        );
      } catch (_) {
        return _thumbnailPlaceholder(ticket);
      }
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CustomImageWidget(
        imageUrl: imageUrl,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        semanticLabel:
            ticket['imageSemanticLabel'] as String? ?? 'Hazard report image',
      );
    }

    return _thumbnailPlaceholder(ticket);
  }

  Widget _thumbnailPlaceholder(Map<String, dynamic> ticket) {
    final severity = ticket['severity'] as String? ?? 'MEDIUM';
    final color = AppTheme.severityColor(severity);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: CustomIconWidget(
          iconName: 'image_not_supported',
          color: color,
          size: 24,
        ),
      ),
    );
  }

  String _formatCoords(dynamic lat, dynamic lng) {
    final latVal = (lat as num?)?.toDouble() ?? 0.0;
    final lngVal = (lng as num?)?.toDouble() ?? 0.0;
    final latDir = latVal >= 0 ? 'N' : 'S';
    final lngDir = lngVal >= 0 ? 'E' : 'W';
    return '${latVal.abs().toStringAsFixed(4)}°$latDir, ${lngVal.abs().toStringAsFixed(4)}°$lngDir';
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return iso;
    }
  }
}
