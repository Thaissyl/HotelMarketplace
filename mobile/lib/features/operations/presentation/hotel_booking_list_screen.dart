import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'hotel_booking_detail_screen.dart';

class HotelBookingListScreen extends ConsumerStatefulWidget {
  const HotelBookingListScreen({
    super.key,
    required this.initialHotelId,
  });

  final String initialHotelId;

  @override
  ConsumerState<HotelBookingListScreen> createState() =>
      _HotelBookingListScreenState();
}

class _HotelBookingListScreenState
    extends ConsumerState<HotelBookingListScreen> {
  String? _hotelId;
  DateTimeRange? _dateRange;
  String? _status;

  @override
  void initState() {
    super.initState();
    _hotelId = widget.initialHotelId;
  }

  Future<void> _selectDateRange() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now.add(const Duration(days: 90)),
          ),
      helpText: 'Filter booking dates',
    );
    if (selected != null && mounted) {
      setState(() => _dateRange = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotels = ref.watch(workingHotelsProvider);
    final hotelId = _hotelId ?? widget.initialHotelId;
    final request = FrontDeskBookingsRequest(hotelId: hotelId);
    final bookings = ref.watch(frontDeskBookingsProvider(request));

    return SrsScreen(
      title: 'Hotel Booking List',
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Booking list actions',
          onSelected: (value) {
            if (value == 'refresh') {
              ref.invalidate(frontDeskBookingsProvider(request));
            } else if (value == 'clear') {
              setState(() {
                _dateRange = null;
                _status = null;
              });
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'refresh', child: Text('Refresh')),
            PopupMenuItem(value: 'clear', child: Text('Clear filters')),
          ],
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          hotels.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const _FilterBox(
              icon: Icons.tune_rounded,
              label: 'Selected Hotel',
              value: 'Current hotel',
              onTap: null,
            ),
            data: (items) {
              final safeHotelId = items.any((item) => item.id == hotelId)
                  ? hotelId
                  : items.firstOrNull?.id;
              if (safeHotelId != null && safeHotelId != _hotelId) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _hotelId = safeHotelId);
                  }
                });
              }
              return DropdownButtonFormField<String>(
                initialValue: safeHotelId,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.tune_rounded),
                  hintText: 'Hotel Filter',
                ),
                items: [
                  for (final hotel in items)
                    DropdownMenuItem(
                      value: hotel.id,
                      child: Text(
                        hotel.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _hotelId = value),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _FilterBox(
            icon: Icons.calendar_month_outlined,
            label: 'Date Range',
            value: _dateRange == null
                ? 'Date Range'
                : '${AppFormatters.displayDate(_dateRange!.start)} - '
                    '${AppFormatters.displayDate(_dateRange!.end)}',
            onTap: _selectDateRange,
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: _status,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.sell_outlined),
              hintText: 'Status Filter',
            ),
            items: const [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('Status Filter'),
              ),
              DropdownMenuItem(value: 'PendingPayment', child: Text('Pending')),
              DropdownMenuItem(value: 'Confirmed', child: Text('Confirmed')),
              DropdownMenuItem(value: 'CheckedIn', child: Text('Checked In')),
              DropdownMenuItem(value: 'CheckedOut', child: Text('Checked Out')),
              DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
              DropdownMenuItem(value: 'Expired', child: Text('Expired')),
              DropdownMenuItem(value: 'NoShow', child: Text('No-show')),
            ],
            onChanged: (value) => setState(() => _status = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SrsSectionTitle('Booking List'),
          const SizedBox(height: AppSpacing.sm),
          bookings.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => _ErrorPanel(
              error: error,
              onRetry: () => ref.invalidate(frontDeskBookingsProvider(request)),
            ),
            data: (items) {
              final filtered = _filter(items);
              if (filtered.isEmpty) {
                return const SrsPanel(
                  child: Text(
                    'No bookings match the selected hotel, dates, and status.',
                  ),
                );
              }

              return Column(
                children: [
                  for (final booking in filtered) ...[
                    _BookingCard(
                      booking: booking,
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => HotelBookingDetailScreen(
                            hotelId: hotelId,
                            booking: booking,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<FrontDeskBookingSummary> _filter(
    List<FrontDeskBookingSummary> source,
  ) {
    final items = source.where((booking) {
      final matchesStatus = _status == null || booking.status == _status;
      final range = _dateRange;
      final overlapsRange = range == null ||
          (booking.checkInDate.isBefore(
                range.end.add(const Duration(days: 1)),
              ) &&
              booking.checkOutDate.isAfter(range.start));
      return matchesStatus && overlapsRange;
    }).toList(growable: false);
    items
        .sort((left, right) => right.createdAtUtc.compareTo(left.createdAtUtc));
    return items;
  }
}

class _FilterBox extends StatelessWidget {
  const _FilterBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outline),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null) const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onOpen});

  final FrontDeskBookingSummary booking;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.bookingCode,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                _BookingLine(
                  icon: Icons.person_outline_rounded,
                  value: booking.guestFullName,
                ),
                _BookingLine(
                  icon: Icons.bed_rounded,
                  value: booking.roomTypeName,
                ),
                _BookingLine(
                  icon: Icons.calendar_today_outlined,
                  value: booking.displayStayDates,
                ),
                _BookingLine(
                  icon: Icons.circle_outlined,
                  value: _readableStatus(booking.status),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: onOpen,
            child: const Text('Open Detail'),
          ),
        ],
      ),
    );
  }
}

class _BookingLine extends StatelessWidget {
  const _BookingLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value.trim().isEmpty ? 'Not available' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppErrorPresenter.friendlyMessage(error)),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

String _readableStatus(String value) {
  if (value == 'PendingPayment') {
    return 'Pending';
  }
  return value.replaceAllMapped(
    RegExp(r'(?<=[a-z])(?=[A-Z])'),
    (match) => ' ',
  );
}
