import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_export.dart';
import '../../core/services/app_data_service.dart';
import '../../core/services/gemini_triage_service.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/live_map_widget.dart';
import '../../widgets/notification_panel_widget.dart';
import '../../widgets/severity_badge_widget.dart';
import '../../widgets/status_badge_widget.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _currentUser;
  late AnimationController _entranceController;
  late TabController _tabController;
  List<Map<String, dynamic>> _assignedTickets = [];
  final Map<String, bool> _verifyingMap = {};
  final Map<String, Map<String, dynamic>?> _verificationResults = {};
  bool _showNotifications = false;
  StreamSubscription<AppNotification>? _notifSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _notifSub = NotificationService.instance.notificationStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      _currentUser = extra;
    } else {
      _currentUser = {
        'id': 3,
        'name': 'Field Crew Dave',
        'role': 'WORKER',
        'email': 'worker@civic.local',
      };
    }
    _loadTickets();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _tabController.dispose();
    _notifSub?.cancel();
    super.dispose();
  }

  void _loadTickets() {
    final workerName = _currentUser?['name'] as String? ?? 'Field Crew Dave';
    setState(() {
      _assignedTickets = AppDataService.instance.getTicketsByWorker(workerName);
    });
  }

  int get _unreadCount => NotificationService.instance.getUnreadCount(
    _currentUser?['id'] as int? ?? 3,
  );

  Future<void> _uploadRepairPhoto(Map<String, dynamic> ticket) async {
    final ticketId = ticket['id'] as String;
    final picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) return;

      setState(() => _verifyingMap[ticketId] = true);

      final bytes = await image.readAsBytes();
      final afterBase64 = base64Encode(bytes);
      final beforeBase64 = ticket['imageBase64'] as String? ?? '';

      Map<String, dynamic> verificationResult;

      if (beforeBase64.isNotEmpty) {
        verificationResult = await GeminiTriageService.verifyRepair(
          beforeImageBase64: beforeBase64,
          afterImageBase64: afterBase64,
          category: ticket['category'] as String? ?? 'Hazard',
        );
      } else {
        verificationResult = await GeminiTriageService.verifyRepair(
          beforeImageBase64: afterBase64,
          afterImageBase64: afterBase64,
          category: ticket['category'] as String? ?? 'Hazard',
        );
      }

      if (verificationResult['verified'] == true) {
        await AppDataService.instance.closeTicket(
          ticketId,
          afterImageBase64: afterBase64,
        );

        final userId = ticket['userId'] as int?;
        if (userId != null) {
          await AppDataService.instance.updateUserKarma(userId, 20);
          await AppDataService.instance.updateTicket(ticketId, {
            'karmaAwarded': true,
          });

          // Notify the citizen their report was resolved
          NotificationService.instance.notifyCitizenReportResolved(
            citizenUserId: userId,
            ticketId: ticketId,
            category: ticket['category'] as String? ?? 'Hazard',
          );
        }
      }

      setState(() {
        _verifyingMap[ticketId] = false;
        _verificationResults[ticketId] = verificationResult;
      });

      _loadTickets();
    } catch (e) {
      setState(() => _verifyingMap[ticketId] = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not access camera. Please try again.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildTaskListView(), _buildMapView()],
                  ),
                ),
              ],
            ),
            if (_showNotifications)
              Positioned(
                top: 60,
                right: 16,
                left: 16,
                child: NotificationPanelWidget(
                  userId: _currentUser?['id'] as int? ?? 3,
                  onClose: () => setState(() => _showNotifications = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark.withAlpha(179),
            border: Border(
              bottom: BorderSide(color: Colors.white.withAlpha(20), width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: CustomIconWidget(
                    iconName: 'engineering',
                    color: Colors.white,
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
                      'CivicPulse AI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Field Crew Portal — ${_currentUser?['name'] ?? 'Worker'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Notification bell
              GestureDetector(
                onTap: () =>
                    setState(() => _showNotifications = !_showNotifications),
                child: Stack(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _showNotifications
                            ? AppTheme.primary.withAlpha(30)
                            : Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _showNotifications
                              ? AppTheme.primary.withAlpha(80)
                              : Colors.white.withAlpha(26),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: CustomIconWidget(
                          iconName: 'notifications_outlined',
                          color: _showNotifications
                              ? AppTheme.primary
                              : const Color(0xFF94A3B8),
                          size: 18,
                        ),
                      ),
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _unreadCount > 9 ? '9+' : '$_unreadCount',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.go(AppRoutes.loginScreen),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withAlpha(26),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: CustomIconWidget(
                      iconName: 'logout',
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        tabs: const [
          Tab(text: 'My Tasks'),
          Tab(text: 'Live Map'),
        ],
      ),
    );
  }

  Widget _buildTaskListView() {
    return Column(
      children: [
        _buildStatsRow(),
        Expanded(
          child: _assignedTickets.isEmpty
              ? const EmptyStateWidget(
                  iconName: 'assignment_turned_in',
                  title: 'No assigned tasks',
                  subtitle:
                      'You have no tickets assigned. Check back after the admin dispatches work.',
                )
              : RefreshIndicator(
                  onRefresh: () async => _loadTickets(),
                  color: AppTheme.primary,
                  backgroundColor: AppTheme.surfaceDark,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    itemCount: _assignedTickets.length,
                    itemBuilder: (context, index) =>
                        _buildTaskCard(_assignedTickets[index], index),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    return LiveMapWidget(
      tickets: _assignedTickets,
      title: 'My Assigned Reports',
    );
  }

  Widget _buildStatsRow() {
    final total = _assignedTickets.length;
    final inProgress = _assignedTickets
        .where((t) => t['status'] == 'IN_PROGRESS')
        .length;
    final closed = _assignedTickets
        .where((t) => t['status'] == 'CLOSED')
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _buildStatChip('Total', total.toString(), AppTheme.primary),
          const SizedBox(width: 10),
          _buildStatChip('In Progress', inProgress.toString(), AppTheme.high),
          const SizedBox(width: 10),
          _buildStatChip('Resolved', closed.toString(), AppTheme.success),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(51), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> ticket, int index) {
    final ticketId = ticket['id'] as String;
    final isVerifying = _verifyingMap[ticketId] == true;
    final verificationResult = _verificationResults[ticketId];
    final isClosed = ticket['status'] == 'CLOSED';

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
        padding: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isClosed
                      ? AppTheme.success.withAlpha(51)
                      : AppTheme.primary.withAlpha(38),
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.severityColor(
                            ticket['severity'] as String? ?? 'MEDIUM',
                          ).withAlpha(38),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: CustomIconWidget(
                            iconName: _categoryIcon(
                              ticket['category'] as String? ?? '',
                            ),
                            color: AppTheme.severityColor(
                              ticket['severity'] as String? ?? 'MEDIUM',
                            ),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                        severity: ticket['severity'] as String? ?? 'MEDIUM',
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
                          ticket['address'] as String? ?? 'Location unknown',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (ticket['aiReason'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withAlpha(13),
                          width: 1,
                        ),
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
                              ticket['aiReason'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (ticket['imageUrl'] != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        ticket['imageUrl'] as String,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        semanticLabel:
                            ticket['imageSemanticLabel'] as String? ??
                            'Before photo of civic hazard',
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: AppTheme.surfaceDark,
                          child: const Center(
                            child: CustomIconWidget(
                              iconName: 'image_not_supported',
                              color: Color(0xFF64748B),
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Before photo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      StatusBadgeWidget(
                        status: ticket['status'] as String? ?? 'IN_PROGRESS',
                      ),
                      const Spacer(),
                      if (!isClosed)
                        _buildVerifyButton(ticket, isVerifying)
                      else
                        _buildClosedBadge(),
                    ],
                  ),
                  if (verificationResult != null) ...[
                    const SizedBox(height: 12),
                    _buildVerificationBanner(verificationResult),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton(Map<String, dynamic> ticket, bool isVerifying) {
    return GestureDetector(
      onTap: isVerifying ? null : () => _uploadRepairPhoto(ticket),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isVerifying
              ? null
              : const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isVerifying ? AppTheme.surfaceDark : null,
          borderRadius: BorderRadius.circular(10),
          border: isVerifying
              ? Border.all(color: Colors.white.withAlpha(26), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isVerifying)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              )
            else
              const CustomIconWidget(
                iconName: 'camera_alt_rounded',
                color: Colors.white,
                size: 14,
              ),
            const SizedBox(width: 6),
            Text(
              isVerifying ? 'Verifying...' : 'Upload Repair Photo',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isVerifying ? const Color(0xFF64748B) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.success.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.success.withAlpha(51), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CustomIconWidget(
            iconName: 'check_circle_outline',
            color: AppTheme.success,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            'Verified & Closed',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner(Map<String, dynamic> result) {
    final verified = result['verified'] == true;
    final confidence = ((result['confidence'] as double?) ?? 0.0) * 100;
    final summary = result['summary'] as String? ?? '';
    final details = result['details'] as String? ?? '';
    final color = verified ? AppTheme.success : AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(64), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: verified ? 'verified' : 'cancel_outlined',
                color: color,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  verified ? 'Repair Verified ✓' : 'Verification Failed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(38),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${confidence.toStringAsFixed(0)}% confidence',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              details,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
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
}
