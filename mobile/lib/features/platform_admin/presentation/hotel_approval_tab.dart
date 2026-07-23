import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/platform_admin_providers.dart';
import '../domain/platform_admin_models.dart';
import 'admin_srs_components.dart';

class HotelApprovalTab extends ConsumerStatefulWidget {
  const HotelApprovalTab({super.key});

  @override
  ConsumerState<HotelApprovalTab> createState() => _HotelApprovalTabState();
}

class _HotelApprovalTabState extends ConsumerState<HotelApprovalTab> {
  final _noteController = TextEditingController();
  String? _selectedId;
  int _page = 0;
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _select(AdminHotel hotel) {
    _noteController.clear();
    setState(() => _selectedId = hotel.id);
  }

  Future<void> _submit(AdminHotel hotel, {required bool approve}) async {
    final note = _noteController.text.trim();
    if (!approve && note.isEmpty) {
      AppErrorPresenter.showSnackBar(
        context,
        'Please enter a rejection reason.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (approve) {
        await ref.read(platformAdminApiProvider).approveHotel(hotel.id);
      } else {
        await ref.read(platformAdminApiProvider).rejectHotel(
              hotelId: hotel.id,
              reason: note,
            );
      }
      ref.invalidate(pendingHotelsProvider);
      if (!mounted) return;
      _noteController.clear();
      setState(() => _selectedId = null);
      AppErrorPresenter.showSnackBar(context, 'Hotel review saved.');
    } catch (error) {
      if (mounted) {
        await AppErrorPresenter.showBottomSheet(context, error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotels = ref.watch(pendingHotelsProvider);
    return AdminRefreshView(
      onRefresh: () async => ref.invalidate(pendingHotelsProvider),
      child: hotels.when(
        loading: () => const AdminLoadingBody(),
        error: (error, _) => AdminErrorBody(
          title: 'Unable to load pending hotels',
          error: error,
          onRetry: () => ref.invalidate(pendingHotelsProvider),
        ),
        data: (items) {
          final selected = adminSelectedItem(
            items,
            _selectedId,
            (item) => item.id,
          );
          final validPage = adminValidPage(
            _page,
            items.length,
            adminListPageSize,
          );
          final visible = adminPage(items, validPage, adminListPageSize);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AdminRecordList(
                title: 'Pending Hotel List',
                emptyMessage: 'No hotels are waiting for review.',
                rows: [
                  for (final hotel in visible)
                    AdminRecordRow(
                      title: adminHotelName(hotel.name),
                      subtitle: hotel.city,
                      status: 'Pending',
                      icon: Icons.apartment_rounded,
                      selected: selected?.id == hotel.id,
                      onTap: () => _select(hotel),
                    ),
                ],
                footer: items.length > adminListPageSize
                    ? AdminPaginationBar(
                        page: validPage,
                        pageCount: adminPageCount(
                          items.length,
                          adminListPageSize,
                        ),
                        onPageChanged: (page) => setState(() => _page = page),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminPanel(
                title: 'Hotel Detail Review',
                child: selected == null
                    ? const AdminSelectionHint(
                        'Select a pending hotel to review.',
                      )
                    : Column(
                        children: [
                          AdminDetailRow(
                            label: 'Hotel',
                            value: adminHotelName(selected.name),
                            icon: Icons.description_rounded,
                          ),
                          AdminDetailRow(
                            label: 'Address',
                            value: '${selected.addressLine}, ${selected.city}',
                            icon: Icons.description_rounded,
                          ),
                          AdminDetailRow(
                            label: 'Contact email',
                            value: selected.contactEmail,
                            icon: Icons.description_rounded,
                          ),
                          AdminDetailRow(
                            label: 'Contact phone',
                            value: selected.contactPhone,
                            icon: Icons.description_rounded,
                          ),
                          AdminDetailRow(
                            label: 'Publication',
                            value: selected.publicationStatus,
                            icon: Icons.description_rounded,
                          ),
                          AdminDetailRow(
                            label: 'Commission',
                            value: adminPercent(
                              selected.defaultCommissionRate,
                            ),
                            icon: Icons.description_rounded,
                            showDivider: false,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AdminTextArea(
                label: 'Admin Note',
                controller: _noteController,
                enabled: selected != null && !_saving,
                hintText: 'Required when rejecting',
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_saving)
                const LinearProgressIndicator()
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: selected == null
                            ? null
                            : () => _submit(selected, approve: true),
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: selected == null
                            ? null
                            : () => _submit(selected, approve: false),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
