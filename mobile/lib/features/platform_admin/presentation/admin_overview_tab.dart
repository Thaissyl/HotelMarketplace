import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../application/platform_admin_providers.dart';
import '../domain/platform_admin_models.dart';
import 'admin_srs_components.dart';

class AdminOverviewTab extends ConsumerStatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  ConsumerState<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends ConsumerState<AdminOverviewTab> {
  String? _hotelId;
  int _tablePage = 0;

  void _showDateRangeLimitation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The current finance API provides lifetime totals only.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(adminFinanceSummaryProvider);
    return AdminRefreshView(
      onRefresh: () async => ref.invalidate(adminFinanceSummaryProvider),
      child: summary.when(
        loading: () => const AdminLoadingBody(),
        error: (error, _) => AdminErrorBody(
          title: 'Unable to load dashboard',
          error: error,
          onRetry: () => ref.invalidate(adminFinanceSummaryProvider),
        ),
        data: (items) {
          final selected = _hotelId == null
              ? items
              : items.where((item) => item.hotelId == _hotelId).toList();
          final gross = selected.fold<double>(
            0,
            (sum, item) => sum + item.grossBookingRevenue,
          );
          final commission = selected.fold<double>(
            0,
            (sum, item) => sum + item.platformCommission,
          );
          final payable = selected.fold<double>(
            0,
            (sum, item) => sum + item.hotelNetReceivable,
          );
          final bookings = selected.fold<int>(
            0,
            (sum, item) => sum + item.successfulBookingCount,
          );
          final validPage = adminValidPage(
            _tablePage,
            selected.length,
            adminTablePageSize,
          );

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DashboardFilter(
                      label: 'Date Range',
                      value: 'All dates',
                      leading: Icons.calendar_today_outlined,
                      onTap: _showDateRangeLimitation,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _HotelFilter(
                      value: _hotelId,
                      items: items,
                      onChanged: (value) {
                        setState(() {
                          _hotelId = value;
                          _tablePage = 0;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _MetricGrid(
                metrics: [
                  _Metric('Bookings', bookings.toString()),
                  _Metric('Gross revenue', AppFormatters.money(gross)),
                  _Metric(
                    'Platform commission',
                    AppFormatters.money(commission),
                  ),
                  _Metric('Hotel payable', AppFormatters.money(payable)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminPanel(
                title: 'Charts',
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: _FinanceChart(items: selected),
              ),
              const SizedBox(height: AppSpacing.lg),
              _FinanceTable(
                items: adminPage(
                  selected,
                  validPage,
                  adminTablePageSize,
                ),
                page: validPage,
                pageCount: adminPageCount(
                  selected.length,
                  adminTablePageSize,
                ),
                onPageChanged: (page) => setState(() => _tablePage = page),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardFilter extends StatelessWidget {
  const _DashboardFilter({
    required this.label,
    required this.value,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: Icon(leading),
              suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _HotelFilter extends StatelessWidget {
  const _HotelFilter({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final List<AdminFinanceSummary> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final uniqueHotels = <String, AdminFinanceSummary>{
      for (final item in items) item.hotelId: item,
    }.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hotel', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.apartment_rounded),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All hotels'),
            ),
            for (final item in uniqueHotels)
              DropdownMenuItem<String?>(
                value: item.hotelId,
                child: Text(
                  adminHotelName(item.hotelName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: cardWidth,
                child: _MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outlineSoft),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surfaceSoft,
            foregroundColor: AppColors.mutedInk,
            child: Icon(Icons.bar_chart_rounded, size: 22),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  maxLines: 3,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metric.value,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Text(
                  '-',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedInk,
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

class _FinanceChart extends StatelessWidget {
  const _FinanceChart({required this.items});

  final List<AdminFinanceSummary> items;

  @override
  Widget build(BuildContext context) {
    final visible = [...items]..sort(
        (left, right) =>
            right.grossBookingRevenue.compareTo(left.grossBookingRevenue),
      );
    final chartItems = visible.take(7).toList(growable: false);

    if (chartItems.isEmpty) {
      return const SizedBox(
        height: 260,
        child: AdminSelectionHint('No finance data is available.'),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 260,
          width: double.infinity,
          child: CustomPaint(
            painter: _FinanceChartPainter(chartItems),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ChartLegend(label: 'Gross revenue', isLine: false),
            SizedBox(width: AppSpacing.lg),
            _ChartLegend(label: 'Hotel net', isLine: true),
          ],
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.label, required this.isLine});

  final String label;
  final bool isLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: isLine ? 2 : 10,
          color: isLine ? AppColors.brandDark : AppColors.accent,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _FinanceChartPainter extends CustomPainter {
  _FinanceChartPainter(this.items);

  final List<AdminFinanceSummary> items;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0;
    const top = 12.0;
    const right = 10.0;
    const bottom = 24.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final maximum = items.fold<double>(
      0,
      (current, item) => math.max(current, item.grossBookingRevenue),
    );
    final scaleMaximum = maximum <= 0 ? 1.0 : maximum;
    final gridPaint = Paint()
      ..color = AppColors.outlineSoft
      ..strokeWidth = 1;

    for (var step = 0; step <= 4; step++) {
      final y = top + chartHeight - (chartHeight * step / 4);
      _drawDashedLine(
        canvas,
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${step * 25}',
          style: const TextStyle(
            color: AppColors.mutedInk,
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(2, y - label.height / 2));
    }

    final slotWidth = chartWidth / items.length;
    final barWidth = math.min(30.0, slotWidth * 0.52);
    final barPaint = Paint()..color = AppColors.accent;
    final linePaint = Paint()
      ..color = AppColors.brandDark
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = AppColors.brandDark;
    final linePath = Path();

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final centerX = left + slotWidth * index + slotWidth / 2;
      final grossRatio = item.grossBookingRevenue / scaleMaximum;
      final grossHeight = chartHeight * grossRatio;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - barWidth / 2,
          top + chartHeight - grossHeight,
          barWidth,
          grossHeight,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(barRect, barPaint);

      final netRatio = item.hotelNetReceivable / scaleMaximum;
      final point = Offset(
        centerX,
        top + chartHeight - chartHeight * netRatio,
      );
      if (index == 0) {
        linePath.moveTo(point.dx, point.dy);
      } else {
        linePath.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(linePath, linePaint);
    for (var index = 0; index < items.length; index++) {
      final centerX = left + slotWidth * index + slotWidth / 2;
      final netRatio = items[index].hotelNetReceivable / scaleMaximum;
      canvas.drawCircle(
        Offset(centerX, top + chartHeight - chartHeight * netRatio),
        4,
        pointPaint,
      );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dash = 5.0;
    const gap = 4.0;
    var x = start.dx;
    while (x < end.dx) {
      canvas.drawLine(
        Offset(x, start.dy),
        Offset(math.min(x + dash, end.dx), end.dy),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _FinanceChartPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}

class _FinanceTable extends StatelessWidget {
  const _FinanceTable({
    required this.items,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
  });

  final List<AdminFinanceSummary> items;
  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      title: 'Tables',
      padding: EdgeInsets.zero,
      child: items.isEmpty
          ? const AdminSelectionHint('No hotel performance data is available.')
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: const WidgetStatePropertyAll(
                      AppColors.surfaceSoft,
                    ),
                    columns: const [
                      DataColumn(label: Text('Hotel')),
                      DataColumn(label: Text('Bookings'), numeric: true),
                      DataColumn(label: Text('Gross revenue'), numeric: true),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: [
                      for (final item in items)
                        DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  adminHotelName(item.hotelName),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(item.successfulBookingCount.toString()),
                            ),
                            DataCell(
                              Text(
                                AppFormatters.money(
                                  item.grossBookingRevenue,
                                ),
                              ),
                            ),
                            DataCell(
                              AdminStatusBadge(
                                status: item.successfulBookingCount > 0
                                    ? 'Active'
                                    : 'No activity',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                AdminPaginationBar(
                  page: page,
                  pageCount: pageCount,
                  onPageChanged: onPageChanged,
                ),
              ],
            ),
    );
  }
}
