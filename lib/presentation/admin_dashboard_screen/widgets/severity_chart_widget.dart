import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class SeverityChartWidget extends StatefulWidget {
  final List<Map<String, dynamic>> tickets;
  final void Function(String? category)? onCategoryTap;

  const SeverityChartWidget({
    super.key,
    required this.tickets,
    this.onCategoryTap,
  });

  @override
  State<SeverityChartWidget> createState() => _SeverityChartWidgetState();
}

class _SeverityChartWidgetState extends State<SeverityChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _touchedIndex = -1;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Map<String, int> get _categoryCounts {
    final counts = <String, int>{};
    for (final t in widget.tickets) {
      final cat = t['category'] as String;
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _categoryCounts;
    final categories = counts.keys.toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(20), width: 1),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'Hazard Distribution',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedCategory != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = null;
                          _touchedIndex = -1;
                        });
                        widget.onCategoryTap?.call(null);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primary.withAlpha(80),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedCategory!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.close,
                              size: 12,
                              color: AppTheme.primary,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Tap bar to filter',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Bar chart
              SizedBox(
                height: 160,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) => BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          (counts.values.isEmpty
                                  ? 5
                                  : counts.values.reduce(
                                          (a, b) => a > b ? a : b,
                                        ) +
                                        1)
                              .toDouble(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: const Color(0xFF1E293B),
                          tooltipRoundedRadius: 8,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${categories[groupIndex]}\n${rod.toY.toInt()} tickets\nTap to filter',
                              GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                        touchCallback: (event, response) {
                          final idx =
                              response?.spot?.touchedBarGroupIndex ?? -1;
                          setState(() {
                            _touchedIndex = idx;
                          });
                          // On tap up, trigger filter
                          if (event is FlTapUpEvent &&
                              idx >= 0 &&
                              idx < categories.length) {
                            final tappedCategory = categories[idx];
                            final newCategory =
                                _selectedCategory == tappedCategory
                                ? null
                                : tappedCategory;
                            setState(() {
                              _selectedCategory = newCategory;
                            });
                            widget.onCategoryTap?.call(newCategory);
                          }
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= categories.length) {
                                return const SizedBox.shrink();
                              }
                              final label = categories[idx];
                              final short = label.length > 8
                                  ? '${label.substring(0, 7)}…'
                                  : label;
                              final isSelected = label == _selectedCategory;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  short,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : const Color(0xFF64748B),
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                            reservedSize: 28,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              if (value % 1 != 0) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                value.toInt().toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: const Color(0xFF64748B),
                                ),
                              );
                            },
                            reservedSize: 24,
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.white.withAlpha(15),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(categories.length, (i) {
                        final cat = categories[i];
                        final count = (counts[cat] ?? 0).toDouble();
                        final isTouched = i == _touchedIndex;
                        final isSelected = cat == _selectedCategory;
                        Color barColor;
                        switch (cat.toLowerCase()) {
                          case 'exposed wires':
                          case 'waterlogging':
                            barColor = AppTheme.critical;
                            break;
                          case 'pothole':
                            barColor = AppTheme.high;
                            break;
                          case 'broken streetlight':
                            barColor = AppTheme.medium;
                            break;
                          default:
                            barColor = AppTheme.low;
                        }
                        // Dim non-selected bars when a filter is active
                        final dimmed = _selectedCategory != null && !isSelected;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: count * _animation.value,
                              color: isTouched || isSelected
                                  ? Colors.white
                                  : dimmed
                                  ? barColor.withAlpha(60)
                                  : barColor,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY:
                                    (counts.values.isEmpty
                                            ? 5
                                            : counts.values.reduce(
                                                    (a, b) => a > b ? a : b,
                                                  ) +
                                                  1)
                                        .toDouble(),
                                color: Colors.white.withAlpha(10),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Legend row
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildLegendItem('Critical', AppTheme.critical),
                  _buildLegendItem('High', AppTheme.high),
                  _buildLegendItem('Medium', AppTheme.medium),
                  _buildLegendItem('Low', AppTheme.low),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
