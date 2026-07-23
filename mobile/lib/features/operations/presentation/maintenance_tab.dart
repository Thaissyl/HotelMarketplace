import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../application/operations_providers.dart';
import '../domain/operations_models.dart';
import 'maintenance_report_issue_screen.dart';
import 'maintenance_request_detail_screen.dart';
import 'maintenance_request_ui.dart';
import 'room_status_board.dart';

class MaintenanceTab extends ConsumerStatefulWidget {
  const MaintenanceTab({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends ConsumerState<MaintenanceTab> {
  String? _status;
  String? _severity;
  String? _roomNumber;

  MaintenanceRequestsRequest get _request =>
      MaintenanceRequestsRequest(hotelId: widget.hotelId);

  Future<void> _refresh() async {
    ref.invalidate(maintenanceRequestsProvider(_request));
    ref.invalidate(maintenanceRoomsProvider(widget.hotelId));
    ref.invalidate(
      physicalRoomsProvider(PhysicalRoomsRequest(hotelId: widget.hotelId)),
    );
    await Future.wait([
      ref.read(maintenanceRequestsProvider(_request).future),
      ref.read(maintenanceRoomsProvider(widget.hotelId).future),
    ]);
  }

  Future<void> _openRequest(MaintenanceRequestItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => MaintenanceRequestDetailScreen(
          hotelId: widget.hotelId,
          request: item,
        ),
      ),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _createRequest() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            MaintenanceReportIssueScreen(hotelId: widget.hotelId),
      ),
    );
    if (created == true) {
      await _refresh();
    }
  }

  Future<void> _openRoomStatusBoard() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => RoomStatusBoard(hotelId: widget.hotelId),
      ),
    );
    ref.invalidate(maintenanceRoomsProvider(widget.hotelId));
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(maintenanceRequestsProvider(_request));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: requests.when(
        data: (items) {
          final rooms = items
              .map((item) => item.roomNumber)
              .where((room) => room.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final visible = items.where((item) {
            final statusMatches = _status == null || item.status == _status;
            final severityMatches =
                _severity == null || item.severity == _severity;
            final roomMatches =
                _roomNumber == null || item.roomNumber == _roomNumber;
            return statusMatches && severityMatches && roomMatches;
          }).toList(growable: false);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _MaintenanceFilters(
                status: _status,
                severity: _severity,
                roomNumber: _roomNumber,
                rooms: rooms,
                onStatusChanged: (value) => setState(() => _status = value),
                onSeverityChanged: (value) => setState(() => _severity = value),
                onRoomChanged: (value) => setState(() => _roomNumber = value),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _createRequest,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Request'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openRoomStatusBoard,
                      icon: const Icon(Icons.grid_view_outlined),
                      label: const Text('Room Status Board'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              const SrsSectionTitle('Request List'),
              const SizedBox(height: AppSpacing.md),
              if (visible.isEmpty)
                const SrsPanel(
                  child: Text(
                    'No maintenance requests match the selected filters.',
                  ),
                )
              else
                for (final item in visible) ...[
                  _MaintenanceRequestCard(
                    item: item,
                    onOpen: () => _openRequest(item),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          );
        },
        error: (error, stackTrace) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            SrsPanel(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Unable to load maintenance requests.'),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _MaintenanceFilters extends StatelessWidget {
  const _MaintenanceFilters({
    required this.status,
    required this.severity,
    required this.roomNumber,
    required this.rooms,
    required this.onStatusChanged,
    required this.onSeverityChanged,
    required this.onRoomChanged,
  });

  final String? status;
  final String? severity;
  final String? roomNumber;
  final List<String> rooms;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onSeverityChanged;
  final ValueChanged<String?> onRoomChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _MaintenanceFilter(
            label: 'Status',
            semanticsLabel: 'Status Filter',
            icon: Icons.filter_list,
            value: status,
            options: const {
              '': 'All statuses',
              'Open': 'Open',
              'InProgress': 'In progress',
              'Resolved': 'Resolved',
              'Released': 'Released',
            },
            onChanged: onStatusChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MaintenanceFilter(
            label: 'Severity',
            semanticsLabel: 'Severity Filter',
            icon: Icons.warning_amber_rounded,
            value: severity,
            options: const {
              '': 'All severities',
              'Low': 'Low',
              'Medium': 'Medium',
              'High': 'High',
              'Critical': 'Critical',
            },
            onChanged: onSeverityChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MaintenanceFilter(
            label: 'Room',
            semanticsLabel: 'Room Filter',
            icon: Icons.meeting_room_outlined,
            value: roomNumber,
            options: {
              '': 'All rooms',
              for (final room in rooms) room: 'Room $room',
            },
            onChanged: onRoomChanged,
          ),
        ),
      ],
    );
  }
}

class _MaintenanceFilter extends StatelessWidget {
  const _MaintenanceFilter({
    required this.label,
    required this.semanticsLabel,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String semanticsLabel;
  final IconData icon;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final displayValue = value == null ? label : options[value] ?? label;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: PopupMenuButton<String>(
        tooltip: semanticsLabel,
        initialValue: value ?? '',
        onSelected: (selected) {
          onChanged(selected.isEmpty ? null : selected);
        },
        itemBuilder: (context) => [
          for (final option in options.entries)
            PopupMenuItem<String>(
              value: option.key,
              child: Text(option.value),
            ),
        ],
        child: Semantics(
          button: true,
          label: semanticsLabel,
          value: value == null ? 'All' : displayValue,
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      displayValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaintenanceRequestCard extends StatelessWidget {
  const _MaintenanceRequestCard({
    required this.item,
    required this.onOpen,
  });

  final MaintenanceRequestItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.surfaceSoft,
                foregroundColor: AppColors.ink,
                child: Icon(maintenanceIssueIcon(item.description), size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room ${item.roomNumber}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: onOpen,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                child: const Text('Open Request'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _RequestTag(
                  label: 'Status: ${maintenanceStatusLabel(item.status)}',
                ),
                _RequestTag(label: 'Severity: ${item.severity}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestTag extends StatelessWidget {
  const _RequestTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
