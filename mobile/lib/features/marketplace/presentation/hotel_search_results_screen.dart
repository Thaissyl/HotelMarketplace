import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_models.dart';
import 'hotel_detail_screen.dart';
import 'marketplace_screen.dart';
import 'widgets/hotel_card.dart';
import 'widgets/marketplace_skeletons.dart';

class HotelSearchResultsScreen extends ConsumerStatefulWidget {
  const HotelSearchResultsScreen({
    super.key,
    required this.query,
  });

  static const String routeName = 'hotel-search-results';
  static const String routePath = '/marketplace/results';

  final HotelSearchQuery query;

  @override
  ConsumerState<HotelSearchResultsScreen> createState() =>
      _HotelSearchResultsScreenState();
}

class _HotelSearchResultsScreenState
    extends ConsumerState<HotelSearchResultsScreen> {
  static const int _pageSize = 5;

  final _pageController = TextEditingController(text: '1');
  _ResultSort _sort = _ResultSort.recommended;
  bool _filterExpanded = true;
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<HotelSearchResult> _prepareResults(List<HotelSearchResult> source) {
    final results =
        source.where(widget.query.filters.allows).toList(growable: false);
    final sorted = [...results];
    switch (_sort) {
      case _ResultSort.recommended:
        break;
      case _ResultSort.lowestPrice:
        sorted.sort(
          (left, right) => left.minimumPricePerNight.compareTo(
            right.minimumPricePerNight,
          ),
        );
      case _ResultSort.highestPrice:
        sorted.sort(
          (left, right) => right.minimumPricePerNight.compareTo(
            left.minimumPricePerNight,
          ),
        );
      case _ResultSort.name:
        sorted.sort((left, right) => left.name.compareTo(right.name));
    }
    return sorted;
  }

  void _goToPage(int page, int pageCount) {
    final next = page.clamp(0, math.max(0, pageCount - 1)).toInt();
    setState(() {
      _pageIndex = next;
      _pageController.text = '${next + 1}';
    });
  }

  void _submitPage(int pageCount) {
    final page = int.tryParse(_pageController.text.trim());
    if (page == null || page < 1 || page > pageCount) {
      _pageController.text = '${_pageIndex + 1}';
      AppErrorPresenter.showSnackBar(
        context,
        'Enter a page number from 1 to $pageCount.',
      );
      return;
    }
    _goToPage(page - 1, pageCount);
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(hotelSearchResultsProvider(widget.query));

    return SrsScreen(
      title: 'Hotel Search Result Screen',
      leading: IconButton(
        tooltip: 'Back to search',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(MarketplaceScreen.routePath);
          }
        },
        icon: const Icon(Icons.arrow_back),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchCriteriaSummary(query: widget.query),
          const SizedBox(height: AppSpacing.md),
          _FilterPanel(
            expanded: _filterExpanded,
            sort: _sort,
            filters: widget.query.filters,
            onToggle: () {
              setState(() => _filterExpanded = !_filterExpanded);
            },
            onSortChanged: (value) {
              setState(() {
                _sort = value;
                _pageIndex = 0;
                _pageController.text = '1';
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          results.when(
            loading: () => const HotelCardSkeletonList(),
            error: (error, stackTrace) => _ResultsError(
              error: error,
              onRetry: () {
                ref.invalidate(hotelSearchResultsProvider(widget.query));
              },
            ),
            data: (source) {
              final hotels = _prepareResults(source);
              if (hotels.isEmpty) {
                return const _EmptyResults();
              }

              final pageCount = (hotels.length / _pageSize).ceil();
              final validPageIndex = _pageIndex.clamp(0, pageCount - 1);
              final page = hotels
                  .skip(validPageIndex * _pageSize)
                  .take(_pageSize)
                  .toList(growable: false);

              return Column(
                children: [
                  for (var index = 0; index < page.length; index++) ...[
                    HotelCard(
                      hotel: page[index],
                      onTap: () {
                        context.push(
                          HotelDetailScreen.pathFor(page[index].id),
                          extra: widget.query,
                        );
                      },
                    ),
                    if (index < page.length - 1)
                      const SizedBox(height: AppSpacing.md),
                  ],
                  if (pageCount > 1) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _Pagination(
                      pageIndex: validPageIndex,
                      pageCount: pageCount,
                      controller: _pageController,
                      onPrevious: validPageIndex == 0
                          ? null
                          : () => _goToPage(validPageIndex - 1, pageCount),
                      onNext: validPageIndex == pageCount - 1
                          ? null
                          : () => _goToPage(validPageIndex + 1, pageCount),
                      onSubmitted: () => _submitPage(pageCount),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _ResultSort { recommended, lowestPrice, highestPrice, name }

class _SearchCriteriaSummary extends StatelessWidget {
  const _SearchCriteriaSummary({required this.query});

  final HotelSearchQuery query;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: SrsSectionTitle('Search Criteria Summary'),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                SrsSummaryRow(
                  label: 'Destination',
                  value: query.location,
                ),
                SrsSummaryRow(
                  label: 'Dates',
                  value:
                      '${AppFormatters.displayDate(query.checkInDate)} - ${AppFormatters.displayDate(query.checkOutDate)}',
                ),
                SrsSummaryRow(
                  label: 'Guests',
                  value: '${query.guestCount}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.expanded,
    required this.sort,
    required this.filters,
    required this.onToggle,
    required this.onSortChanged,
  });

  final bool expanded;
  final _ResultSort sort;
  final HotelSearchFilters filters;
  final VoidCallback onToggle;
  final ValueChanged<_ResultSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Expanded(child: SrsSectionTitle('Filter Panel')),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<_ResultSort>(
                    initialValue: sort,
                    decoration: const InputDecoration(
                      labelText: 'Sort results',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _ResultSort.recommended,
                        child: Text('Recommended'),
                      ),
                      DropdownMenuItem(
                        value: _ResultSort.lowestPrice,
                        child: Text('Lowest price'),
                      ),
                      DropdownMenuItem(
                        value: _ResultSort.highestPrice,
                        child: Text('Highest price'),
                      ),
                      DropdownMenuItem(
                        value: _ResultSort.name,
                        child: Text('Hotel name'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onSortChanged(value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _filterSummary(filters),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.section,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.manage_search,
              size: 64,
              color: AppColors.subtleInk,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No hotels match your search criteria.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Please adjust your search or filters.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const dash = 7.0;
    const gap = 5.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(8),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + dash, metric.length),
          ),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResultsError extends StatelessWidget {
  const _ResultsError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      child: Column(
        children: [
          Text(
            AppErrorPresenter.friendlyMessage(error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.pageIndex,
    required this.pageCount,
    required this.controller,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmitted,
  });

  final int pageIndex;
  final int pageCount;
  final TextEditingController controller;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 96,
          child: OutlinedButton(
            onPressed: onPrevious,
            child: const Text('Previous'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 64,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              helperText: 'of $pageCount',
              helperMaxLines: 1,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 76,
          child: OutlinedButton(
            onPressed: onNext,
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }
}

String _filterSummary(HotelSearchFilters filters) {
  final parts = <String>[];
  if (filters.minimumPrice != null) {
    parts.add('From ${AppFormatters.money(filters.minimumPrice!)}');
  }
  if (filters.maximumPrice != null) {
    parts.add('Up to ${AppFormatters.money(filters.maximumPrice!)}');
  }
  if (filters.amenities.isNotEmpty) {
    parts.add(filters.amenities.join(', '));
  }
  if (filters.availableOnly) {
    parts.add('Available rooms only');
  }
  return parts.isEmpty ? 'No additional filters' : parts.join(' - ');
}
