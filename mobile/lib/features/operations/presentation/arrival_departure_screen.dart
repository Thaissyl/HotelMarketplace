import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/utils/app_formatters.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'check_out_screen.dart';
import 'front_desk_components.dart';
import 'room_assignment_screen.dart';
import 'walk_in_screen.dart';

enum ArrivalDepartureListType {
  arrivals('Arrivals'),
  departures('Departures'),
  inHouse('In-house'),
  noShow('No-show');

  const ArrivalDepartureListType(this.label);

  final String label;
}

enum _ArrivalListMenuAction { walkIn, refresh }

class ArrivalDepartureScreen extends ConsumerStatefulWidget {
  const ArrivalDepartureScreen({
    super.key,
    required this.hotelId,
    this.initialType = ArrivalDepartureListType.arrivals,
  });

  final String hotelId;
  final ArrivalDepartureListType initialType;

  @override
  ConsumerState<ArrivalDepartureScreen> createState() =>
      _ArrivalDepartureScreenState();
}

class _ArrivalDepartureScreenState
    extends ConsumerState<ArrivalDepartureScreen> {
  late ArrivalDepartureListType _type;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _date = DateUtils.dateOnly(DateTime.now());
  }

  FrontDeskBookingsRequest get _confirmedRequest => FrontDeskBookingsRequest(
        hotelId: widget.hotelId,
        status: FrontDeskBookingListStatus.confirmed,
      );

  FrontDeskBookingsRequest get _checkedInRequest => FrontDeskBookingsRequest(
        hotelId: widget.hotelId,
        status: FrontDeskBookingListStatus.checkedIn,
      );

  Future<void> _refresh() async {
    ref
      ..invalidate(frontDeskBookingsProvider(_confirmedRequest))
      ..invalidate(frontDeskBookingsProvider(_checkedInRequest));
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected != null && mounted) {
      setState(() => _date = DateUtils.dateOnly(selected));
    }
  }

  Future<void> _openWalkIn() async {
    final result = await Navigator.of(context).push<FrontDeskBookingResult>(
      MaterialPageRoute(
        builder: (context) => WalkInBookingScreen(hotelId: widget.hotelId),
      ),
    );
    if (result != null && mounted) {
      await _refresh();
      if (mounted) {
        showFrontDeskResult(context, result);
      }
    }
  }

  Future<void> _openBooking(FrontDeskBookingSummary booking) async {
    FrontDeskBookingResult? result;
    switch (_type) {
      case ArrivalDepartureListType.arrivals:
        result = await Navigator.of(context).push<FrontDeskBookingResult>(
          MaterialPageRoute(
            builder: (context) => RoomAssignmentScreen(
              hotelId: widget.hotelId,
              booking: booking,
            ),
          ),
        );
        break;
      case ArrivalDepartureListType.departures:
      case ArrivalDepartureListType.inHouse:
        result = await Navigator.of(context).push<FrontDeskBookingResult>(
          MaterialPageRoute(
            builder: (context) => CheckOutScreen(
              hotelId: widget.hotelId,
              booking: booking,
            ),
          ),
        );
        break;
      case ArrivalDepartureListType.noShow:
        result = await showDialog<FrontDeskBookingResult>(
          context: context,
          builder: (context) => _NoShowDialog(
            hotelId: widget.hotelId,
            booking: booking,
          ),
        );
        break;
    }

    if (result != null && mounted) {
      await _refresh();
      if (mounted) {
        showFrontDeskResult(context, result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = ref.watch(frontDeskBookingsProvider(_confirmedRequest));
    final checkedIn = ref.watch(frontDeskBookingsProvider(_checkedInRequest));

    return FrontDeskRouteScaffold(
      title: 'Arrival / Departure List',
      actions: [
        PopupMenuButton<_ArrivalListMenuAction>(
          onSelected: (value) {
            switch (value) {
              case _ArrivalListMenuAction.walkIn:
                _openWalkIn();
                break;
              case _ArrivalListMenuAction.refresh:
                _refresh();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _ArrivalListMenuAction.walkIn,
              child: Text('Create Walk-in Booking'),
            ),
            PopupMenuItem(
              value: _ArrivalListMenuAction.refresh,
              child: Text('Refresh List'),
            ),
          ],
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _DateFilter(date: _date, onTap: _pickDate),
            const SizedBox(height: AppSpacing.sm),
            _ListTypeSelector(
              value: _type,
              onChanged: (value) => setState(() => _type = value),
            ),
            const SizedBox(height: AppSpacing.md),
            if (confirmed.isLoading || checkedIn.isLoading)
              const FrontDeskLoadingState()
            else if (confirmed.hasError)
              FrontDeskErrorState(
                error: confirmed.error!,
                onRetry: _refresh,
                title: 'Unable to load arrival bookings',
              )
            else if (checkedIn.hasError)
              FrontDeskErrorState(
                error: checkedIn.error!,
                onRetry: _refresh,
                title: 'Unable to load in-house bookings',
              )
            else
              _BookingList(
                type: _type,
                date: _date,
                confirmed: confirmed.value ?? const [],
                checkedIn: checkedIn.value ?? const [],
                onOpenBooking: _openBooking,
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _DateFilter extends StatelessWidget {
  const _DateFilter({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FrontDeskPanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date Filter',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      AppFormatters.displayDate(date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListTypeSelector extends StatelessWidget {
  const _ListTypeSelector({
    required this.value,
    required this.onChanged,
  });

  final ArrivalDepartureListType value;
  final ValueChanged<ArrivalDepartureListType> onChanged;

  @override
  Widget build(BuildContext context) {
    return FrontDeskPanel(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('List Type', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                for (var index = 0;
                    index < ArrivalDepartureListType.values.length;
                    index++) ...[
                  if (index > 0)
                    Container(
                      width: 1,
                      height: 54,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  Expanded(
                    child: InkWell(
                      onTap: () => onChanged(
                        ArrivalDepartureListType.values[index],
                      ),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        color: value == ArrivalDepartureListType.values[index]
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                            : null,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            child: Text(
                              ArrivalDepartureListType.values[index].label,
                              style: value ==
                                      ArrivalDepartureListType.values[index]
                                  ? const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({
    required this.type,
    required this.date,
    required this.confirmed,
    required this.checkedIn,
    required this.onOpenBooking,
  });

  final ArrivalDepartureListType type;
  final DateTime date;
  final List<FrontDeskBookingSummary> confirmed;
  final List<FrontDeskBookingSummary> checkedIn;
  final ValueChanged<FrontDeskBookingSummary> onOpenBooking;

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Column(
        key: ValueKey('${type.name}-${date.toIso8601String()}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${type.label} (${items.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            FrontDeskEmptyState(
              title: 'No ${type.label.toLowerCase()}',
              message: _emptyMessage(),
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const SizedBox(height: AppSpacing.sm),
              _BookingListCard(
                booking: items[index],
                type: type,
                onOpen: () => onOpenBooking(items[index]),
              ),
            ],
        ],
      ),
    );
  }

  List<FrontDeskBookingSummary> _visibleItems() {
    final source = switch (type) {
      ArrivalDepartureListType.arrivals ||
      ArrivalDepartureListType.noShow =>
        confirmed,
      ArrivalDepartureListType.departures ||
      ArrivalDepartureListType.inHouse =>
        checkedIn,
    };

    final result = source.where((booking) {
      return switch (type) {
        ArrivalDepartureListType.arrivals =>
          DateUtils.isSameDay(booking.checkInDate, date),
        ArrivalDepartureListType.departures =>
          DateUtils.isSameDay(booking.checkOutDate, date),
        ArrivalDepartureListType.inHouse => true,
        ArrivalDepartureListType.noShow =>
          DateUtils.dateOnly(booking.checkInDate).isBefore(date),
      };
    }).toList(growable: false);
    result.sort((left, right) => left.bookingCode.compareTo(right.bookingCode));
    return result;
  }

  String _emptyMessage() {
    return switch (type) {
      ArrivalDepartureListType.inHouse =>
        'There are no guests currently checked in.',
      ArrivalDepartureListType.noShow =>
        'No confirmed bookings have missed check-in by ${AppFormatters.displayDate(date)}.',
      ArrivalDepartureListType.arrivals ||
      ArrivalDepartureListType.departures =>
        'There are no matching bookings for ${AppFormatters.displayDate(date)}.',
    };
  }
}

class _BookingListCard extends StatelessWidget {
  const _BookingListCard({
    required this.booking,
    required this.type,
    required this.onOpen,
  });

  final FrontDeskBookingSummary booking;
  final ArrivalDepartureListType type;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final operationDate = type == ArrivalDepartureListType.departures
        ? booking.checkOutDate
        : booking.checkInDate;
    final status = switch (type) {
      ArrivalDepartureListType.arrivals => 'Arriving',
      ArrivalDepartureListType.departures => 'Departing',
      ArrivalDepartureListType.inHouse => 'In-house',
      ArrivalDepartureListType.noShow => 'No-show review',
    };

    return FrontDeskPanel(
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
                _CompactLine(
                  icon: Icons.person_outline,
                  text: booking.guestFullName,
                ),
                _CompactLine(
                  icon: Icons.bed_outlined,
                  text: booking.roomTypeName.isEmpty
                      ? 'Room type unavailable'
                      : booking.roomTypeName,
                ),
                _CompactLine(
                  icon: Icons.calendar_month_outlined,
                  text: AppFormatters.displayDate(operationDate),
                ),
                _CompactLine(
                  icon: Icons.schedule_outlined,
                  text: 'Status: $status',
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: onOpen,
            child: const Text('Open Booking'),
          ),
        ],
      ),
    );
  }
}

class _CompactLine extends StatelessWidget {
  const _CompactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _NoShowDialog extends ConsumerStatefulWidget {
  const _NoShowDialog({
    required this.hotelId,
    required this.booking,
  });

  final String hotelId;
  final FrontDeskBookingSummary booking;

  @override
  ConsumerState<_NoShowDialog> createState() => _NoShowDialogState();
}

class _NoShowDialogState extends ConsumerState<_NoShowDialog> {
  final _reason = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason.text.trim().length < 3) {
      setState(() => _error = 'Enter a clear operational reason.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(operationsApiProvider).markBookingNoShow(
            hotelId: widget.hotelId,
            bookingId: widget.booking.bookingId,
            reason: _reason.text,
          );
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(
          context,
          error,
          title: 'No-show not recorded',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm No-show'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.booking.guestFullName} - ${widget.booking.bookingCode}',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reason,
            enabled: !_submitting,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Operational Reason',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Mark No-show'),
        ),
      ],
    );
  }
}
