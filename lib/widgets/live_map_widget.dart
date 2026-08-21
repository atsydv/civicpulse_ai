import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_export.dart';
import '../core/services/location_service.dart';
import '../widgets/severity_badge_widget.dart';
import '../widgets/status_badge_widget.dart';

class LiveMapWidget extends StatefulWidget {
  final List<Map<String, dynamic>> tickets;
  final String title;

  const LiveMapWidget({super.key, required this.tickets, required this.title});

  @override
  State<LiveMapWidget> createState() => _LiveMapWidgetState();
}

class _LiveMapWidgetState extends State<LiveMapWidget> {
  Map<String, dynamic>? _selectedTicket;
  final MapController _mapController = MapController();
  LatLng _centerLocation = const LatLng(
    LocationService.defaultLat,
    LocationService.defaultLng,
  );
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    try {
      final loc = await LocationService.getCurrentLocation();
      final lat = loc['latitude'] ?? LocationService.defaultLat;
      final lng = loc['longitude'] ?? LocationService.defaultLng;
      if (mounted) {
        setState(() {
          _centerLocation = LatLng(lat, lng);
          _locationLoaded = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(_centerLocation, 13.0);
          } catch (_) {}
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationLoaded = true;
        });
      }
    }
  }

  Color _markerColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFEF4444);
      case 'HIGH':
        return const Color(0xFFFF7722);
      case 'MEDIUM':
        return const Color(0xFFEAB308);
      case 'LOW':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF64748B);
    }
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _centerLocation,
                  initialZoom: 13.0,
                  minZoom: 3.0,
                  maxZoom: 19.0,
                  onTap: (_, __) => setState(() => _selectedTicket = null),
                ),
                children: [
                  TileLayer(
                    // Primary: OpenStreetMap with subdomains for reliability
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.civicpulse.app',
                    maxNativeZoom: 19,
                    keepBuffer: 5,
                    // Fallback to CartoDB light tiles if OSM fails
                    fallbackUrl:
                        'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                    tileProvider: NetworkTileProvider(),
                  ),
                  MarkerLayer(
                    markers: [
                      // User location marker (blue dot)
                      if (_locationLoaded)
                        Marker(
                          point: _centerLocation,
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withAlpha(160),
                                  blurRadius: 12,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: CustomIconWidget(
                                iconName: 'my_location',
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      // Report markers
                      ...widget.tickets.map((ticket) {
                        final lat =
                            (ticket['latitude'] as num?)?.toDouble() ??
                            LocationService.defaultLat;
                        final lng =
                            (ticket['longitude'] as num?)?.toDouble() ??
                            LocationService.defaultLng;
                        final severity =
                            ticket['severity'] as String? ?? 'MEDIUM';
                        final color = _markerColor(severity);

                        return Marker(
                          point: LatLng(lat, lng),
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedTicket = ticket),
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withAlpha(128),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: CustomIconWidget(
                                  iconName: _categoryIcon(
                                    ticket['category'] as String? ?? '',
                                  ),
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
              // Legend
              Positioned(top: 12, right: 12, child: _buildLegend()),
              // Ticket count badge
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark.withAlpha(230),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withAlpha(30),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CustomIconWidget(
                        iconName: 'location_on',
                        color: AppTheme.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.tickets.length} Reports',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Re-center button
              Positioned(
                bottom: _selectedTicket != null ? 220 : 16,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    _mapController.move(_centerLocation, 13.0);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark.withAlpha(230),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(30),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(80),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: CustomIconWidget(
                        iconName: 'my_location',
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Selected ticket info panel
        if (_selectedTicket != null) _buildTicketInfoPanel(_selectedTicket!),
      ],
    );
  }

  Widget _buildLegend() {
    final items = [
      ('CRITICAL', const Color(0xFFEF4444)),
      ('HIGH', const Color(0xFFFF7722)),
      ('MEDIUM', const Color(0xFFEAB308)),
      ('LOW', const Color(0xFF10B981)),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(30), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.$2,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.$1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTicketInfoPanel(Map<String, dynamic> ticket) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(20), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket['category'] as String? ?? 'Hazard',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      ticket['id'] as String? ?? '',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              SeverityBadgeWidget(
                severity: ticket['severity'] as String? ?? 'MEDIUM',
                showGlow: false,
              ),
              const SizedBox(width: 8),
              StatusBadgeWidget(
                status: ticket['status'] as String? ?? 'TRIAGED',
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                  ticket['address'] as String? ?? 'Prayagraj',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (ticket['aiReason'] != null) ...[
            const SizedBox(height: 6),
            Text(
              ticket['aiReason'] as String,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (ticket['assignedTo'] != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const CustomIconWidget(
                  iconName: 'engineering',
                  color: Color(0xFF64748B),
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  ticket['assignedTo'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
