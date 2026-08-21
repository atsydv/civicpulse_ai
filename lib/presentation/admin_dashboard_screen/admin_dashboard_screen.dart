import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../core/services/app_data_service.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/live_map_widget.dart';
import '../../widgets/notification_panel_widget.dart';
import './widgets/kpi_metric_card_widget.dart';
import './widgets/severity_chart_widget.dart';
import './widgets/ticket_queue_widget.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _currentUser;
  late AnimationController _entranceController;
  late TabController _tabController;
  int _selectedFilterIndex = 0;
  String? _selectedCategoryFilter;
  bool _showNotifications = false;
  StreamSubscription<AppNotification>? _notifSub;

  final List<String> _filters = ['All', 'Critical', 'In Progress', 'Resolved'];

  late List<Map<String, dynamic>> _tickets;

  @override
  void initState() {
    super.initState();
    _tickets = _getPriorityOrderedTickets();
    _tabController = TabController(length: 2, vsync: this);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // Listen for new notifications to refresh badge
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
        'id': 2,
        'name': 'Commissioner Torres',
        'role': 'ADMIN',
        'email': 'admin@civic.local',
      };
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _tabController.dispose();
    _notifSub?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _getPriorityOrderedTickets() {
    final tickets = List<Map<String, dynamic>>.from(
      AppDataService.instance.tickets,
    );
    final users = AppDataService.instance.users;

    int severityWeight(String s) {
      switch (s.toUpperCase()) {
        case 'CRITICAL':
          return 4;
        case 'HIGH':
          return 3;
        case 'MEDIUM':
          return 2;
        case 'LOW':
          return 1;
        default:
          return 0;
      }
    }

    int reporterKarma(Map<String, dynamic> ticket) {
      final userId = ticket['userId'] as int?;
      if (userId == null) return 0;
      try {
        final user = users.firstWhere((u) => u['id'] == userId);
        return (user['karma'] as int?) ?? 0;
      } catch (_) {
        return 0;
      }
    }

    tickets.sort((a, b) {
      final sevA = severityWeight(a['severity'] as String? ?? 'LOW');
      final sevB = severityWeight(b['severity'] as String? ?? 'LOW');
      if (sevA != sevB) return sevB.compareTo(sevA);
      return reporterKarma(b).compareTo(reporterKarma(a));
    });

    return tickets;
  }

  List<Map<String, dynamic>> get _filteredTickets {
    List<Map<String, dynamic>> result;
    switch (_selectedFilterIndex) {
      case 1:
        result = _tickets.where((t) => t['severity'] == 'CRITICAL').toList();
        break;
      case 2:
        result = _tickets.where((t) => t['status'] == 'IN_PROGRESS').toList();
        break;
      case 3:
        result = _tickets.where((t) => t['status'] == 'CLOSED').toList();
        break;
      default:
        result = _tickets;
    }
    // Apply category filter from chart
    if (_selectedCategoryFilter != null) {
      result = result
          .where((t) => t['category'] == _selectedCategoryFilter)
          .toList();
    }
    return result;
  }

  int get _totalReports => _tickets.length;
  int get _criticalHazards =>
      _tickets.where((t) => t['severity'] == 'CRITICAL').length;
  int get _activeInProgress =>
      _tickets.where((t) => t['status'] == 'IN_PROGRESS').length;
  int get _resolvedTickets =>
      _tickets.where((t) => t['status'] == 'CLOSED').length;

  int get _unreadCount => NotificationService.instance.getUnreadCount(
    _currentUser?['id'] as int? ?? 2,
  );

  void _assignWorker(String ticketId, String workerName) async {
    await AppDataService.instance.assignWorker(ticketId, workerName);

    // Find the ticket and notify the worker
    final ticket = AppDataService.instance.tickets.firstWhere(
      (t) => t['id'] == ticketId,
      orElse: () => {},
    );
    if (ticket.isNotEmpty) {
      final worker = AppDataService.instance.getUserByName(workerName);
      if (worker != null) {
        NotificationService.instance.notifyWorkerAssigned(
          workerUserId: worker['id'] as int,
          ticketId: ticketId,
          category: ticket['category'] as String? ?? 'Hazard',
          severity: ticket['severity'] as String? ?? 'MEDIUM',
          address: ticket['address'] as String? ?? 'Prayagraj',
        );
      }
    }

    setState(() {
      _tickets = _getPriorityOrderedTickets();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ticket $ticketId dispatched to $workerName',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

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
                    children: [_buildListView(isTablet), _buildMapView()],
                  ),
                ),
              ],
            ),
            // Notification panel overlay
            if (_showNotifications)
              Positioned(
                top: 60,
                right: 16,
                left: 16,
                child: NotificationPanelWidget(
                  userId: _currentUser?['id'] as int? ?? 2,
                  onClose: () => setState(() => _showNotifications = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
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
                colors: [AppTheme.primary, AppTheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: CustomIconWidget(
                iconName: 'admin_panel_settings',
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
                  'Admin Command Center',
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
                        color: AppTheme.critical,
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
                border: Border.all(color: Colors.white.withAlpha(26), width: 1),
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
            colors: [AppTheme.primary, AppTheme.secondary],
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
          Tab(text: 'Dispatch Queue'),
          Tab(text: 'Live Map'),
        ],
      ),
    );
  }

  Widget _buildListView(bool isTablet) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildKpiSection(isTablet)),
          SliverToBoxAdapter(child: _buildChartSection()),
          SliverToBoxAdapter(child: _buildFilterSection()),
          SliverToBoxAdapter(child: _buildQueueHeader()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: TicketQueueWidget(
              tickets: _filteredTickets,
              onAssignWorker: _assignWorker,
              isTablet: isTablet,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return LiveMapWidget(tickets: _tickets, title: 'All Reports — Prayagraj');
  }

  Widget _buildKpiSection(bool isTablet) {
    final kpis = [
      {
        'label': 'Total Reports',
        'value': _totalReports,
        'icon': 'receipt_long',
        'color': AppTheme.primary,
        'delta': 'All time',
        'deltaPositive': true,
      },
      {
        'label': 'Critical Hazards',
        'value': _criticalHazards,
        'icon': 'warning_amber_rounded',
        'color': AppTheme.critical,
        'delta': 'Needs attention',
        'deltaPositive': false,
      },
      {
        'label': 'Active Tasks',
        'value': _activeInProgress,
        'icon': 'engineering',
        'color': AppTheme.high,
        'delta': 'In progress',
        'deltaPositive': true,
      },
      {
        'label': 'Resolved',
        'value': _resolvedTickets,
        'icon': 'check_circle_outline',
        'color': AppTheme.success,
        'delta': 'Closed tickets',
        'deltaPositive': true,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: isTablet
          ? Row(
              children: kpis
                  .map(
                    (kpi) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: KpiMetricCardWidget(kpi: kpi),
                      ),
                    ),
                  )
                  .toList(),
            )
          : GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: kpis
                  .map((kpi) => KpiMetricCardWidget(kpi: kpi))
                  .toList(),
            ),
    );
  }

  Widget _buildChartSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SeverityChartWidget(
        tickets: _tickets,
        onCategoryTap: (category) {
          setState(() {
            _selectedCategoryFilter = category;
          });
        },
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.asMap().entries.map((entry) {
            final isSelected = entry.key == _selectedFilterIndex;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilterIndex = entry.key),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.secondary],
                        )
                      : null,
                  color: isSelected ? null : Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white.withAlpha(20),
                    width: 1,
                  ),
                ),
                child: Text(
                  entry.value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildQueueHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const CustomIconWidget(
            iconName: 'queue',
            color: AppTheme.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Dispatch Queue',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_filteredTickets.length} tickets',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
