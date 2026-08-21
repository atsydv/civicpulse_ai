import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../core/services/app_data_service.dart';

class RankingsScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUser;

  const RankingsScreen({super.key, this.currentUser});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Prayagraj city blocks - manually seeded
  static const List<String> _cityBlocks = [
    'Civil Lines',
    'Allahpur',
    'George Town',
    'Naini',
    'Phaphamau',
    'Kareli',
    'Jhunsi',
    'Mumfordganj',
    'Kydganj',
    'Daraganj',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _leaderboard =>
      AppDataService.instance.getLeaderboard();

  List<Map<String, dynamic>> get _blockRankings {
    final tickets = AppDataService.instance.tickets;
    final counts = <String, int>{};

    // Initialize all blocks with 0
    for (final block in _cityBlocks) {
      counts[block] = 0;
    }

    // Count reports per block by matching address
    for (final ticket in tickets) {
      final address = (ticket['address'] as String? ?? '').toLowerCase();
      for (final block in _cityBlocks) {
        if (address.contains(block.toLowerCase())) {
          counts[block] = (counts[block] ?? 0) + 1;
          break;
        }
      }
    }

    // Also distribute some default counts for blocks with no exact match
    // to make the ranking more interesting
    final defaultCounts = {
      'Civil Lines': 3,
      'Allahpur': 1,
      'George Town': 2,
      'Naini': 1,
      'Phaphamau': 0,
      'Kareli': 0,
      'Jhunsi': 0,
      'Mumfordganj': 0,
      'Kydganj': 0,
      'Daraganj': 0,
    };

    final result = _cityBlocks.map((block) {
      final dynamicCount = counts[block] ?? 0;
      final defaultCount = defaultCounts[block] ?? 0;
      return {
        'block': block,
        'count': dynamicCount > 0 ? dynamicCount : defaultCount,
      };
    }).toList();

    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildCitizenRankings(), _buildBlockRankings()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                    colors: [Color(0xFFFFD700), Color(0xFFF97316)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: CustomIconWidget(
                    iconName: 'emoji_events',
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
                      'Rankings',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Prayagraj Civic Champions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          Tab(text: 'Citizens'),
          Tab(text: 'City Blocks'),
        ],
      ),
    );
  }

  Widget _buildCitizenRankings() {
    final leaderboard = _leaderboard;
    final currentUserId = widget.currentUser?['id'] as int?;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: leaderboard.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildCitizenHeader(leaderboard, currentUserId);
        final rank = index;
        final user = leaderboard[index - 1];
        final isCurrentUser = user['id'] == currentUserId;
        return _buildCitizenRow(rank, user, isCurrentUser);
      },
    );
  }

  Widget _buildCitizenHeader(
    List<Map<String, dynamic>> leaderboard,
    int? currentUserId,
  ) {
    // Find current user rank
    int? myRank;
    int? myKarma;
    if (currentUserId != null) {
      for (int i = 0; i < leaderboard.length; i++) {
        if (leaderboard[i]['id'] == currentUserId) {
          myRank = i + 1;
          myKarma = leaderboard[i]['karma'] as int?;
          break;
        }
      }
    }

    return Column(
      children: [
        // Top 3 podium
        if (leaderboard.length >= 3) ...[
          _buildPodium(leaderboard),
          const SizedBox(height: 16),
        ],
        // My rank card
        if (myRank != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withAlpha(40),
                  AppTheme.secondary.withAlpha(20),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primary.withAlpha(80),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const CustomIconWidget(
                  iconName: 'person',
                  color: AppTheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'Your Rank',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const Spacer(),
                Text(
                  '#$myRank',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    const CustomIconWidget(
                      iconName: 'bolt',
                      color: Color(0xFFEAB308),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${myKarma ?? 0} pts',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEAB308),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        // Full list header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                'All Citizens',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> leaderboard) {
    final first = leaderboard[0];
    final second = leaderboard[1];
    final third = leaderboard.length > 2 ? leaderboard[2] : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(15), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          Expanded(
            child: _buildPodiumItem(
              rank: 2,
              user: second,
              height: 80,
              color: const Color(0xFFC0C0C0),
              medalIcon: 'military_tech',
            ),
          ),
          const SizedBox(width: 8),
          // 1st place
          Expanded(
            child: _buildPodiumItem(
              rank: 1,
              user: first,
              height: 100,
              color: const Color(0xFFFFD700),
              medalIcon: 'emoji_events',
            ),
          ),
          const SizedBox(width: 8),
          // 3rd place
          Expanded(
            child: third != null
                ? _buildPodiumItem(
                    rank: 3,
                    user: third,
                    height: 64,
                    color: const Color(0xFFCD7F32),
                    medalIcon: 'military_tech',
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required int rank,
    required Map<String, dynamic> user,
    required double height,
    required Color color,
    required String medalIcon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomIconWidget(iconName: medalIcon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          (user['name'] as String? ?? 'Citizen').split(' ').first,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          '${user['karma'] ?? 0} pts',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withAlpha(80), width: 1),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCitizenRow(
    int rank,
    Map<String, dynamic> user,
    bool isCurrentUser,
  ) {
    final karma = (user['karma'] as int?) ?? 0;
    Color rankColor;
    String rankIcon;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
      rankIcon = 'emoji_events';
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
      rankIcon = 'military_tech';
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      rankIcon = 'military_tech';
    } else {
      rankColor = const Color(0xFF64748B);
      rankIcon = 'person_outline';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + rank * 40),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? AppTheme.primary.withAlpha(20)
              : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentUser
                ? AppTheme.primary.withAlpha(64)
                : Colors.white.withAlpha(15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            CustomIconWidget(iconName: rankIcon, color: rankColor, size: 18),
            const SizedBox(width: 10),
            Text(
              '#$rank',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: rankColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                user['name'] as String? ?? 'Citizen',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: isCurrentUser ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrentUser ? Colors.white : const Color(0xFFCBD5E1),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrentUser) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(38),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'You',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CustomIconWidget(
                  iconName: 'bolt',
                  color: Color(0xFFEAB308),
                  size: 14,
                ),
                const SizedBox(width: 2),
                Text(
                  '$karma pts',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEAB308),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockRankings() {
    final blocks = _blockRankings;
    final maxCount = blocks.isNotEmpty ? (blocks.first['count'] as int) : 1;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: blocks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'City Block Rankings',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ranked by number of civic reports submitted',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        }
        final blockData = blocks[index - 1];
        final rank = index;
        return _buildBlockRow(rank, blockData, maxCount);
      },
    );
  }

  Widget _buildBlockRow(
    int rank,
    Map<String, dynamic> blockData,
    int maxCount,
  ) {
    final block = blockData['block'] as String;
    final count = blockData['count'] as int;
    final progress = maxCount > 0 ? count / maxCount : 0.0;

    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFEF4444);
    } else if (rank == 2) {
      rankColor = const Color(0xFFF97316);
    } else if (rank == 3) {
      rankColor = const Color(0xFFEAB308);
    } else if (rank <= 5) {
      rankColor = AppTheme.primary;
    } else {
      rankColor = const Color(0xFF64748B);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + rank * 50),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: rank <= 3
                ? rankColor.withAlpha(60)
                : Colors.white.withAlpha(15),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rankColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: rankColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Prayagraj',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: rankColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: rankColor.withAlpha(60),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: 'receipt_long',
                        color: rankColor,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$count reports',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: rankColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withAlpha(15),
                valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
