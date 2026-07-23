import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../application/platform_admin_providers.dart';
import '../domain/platform_admin_models.dart';
import 'admin_srs_components.dart';

class CommissionManagementTab extends ConsumerStatefulWidget {
  const CommissionManagementTab({super.key});

  @override
  ConsumerState<CommissionManagementTab> createState() =>
      _CommissionManagementTabState();
}

class _CommissionManagementTabState
    extends ConsumerState<CommissionManagementTab> {
  final _formKey = GlobalKey<FormState>();
  final _rateController = TextEditingController();
  final _noteController = TextEditingController();
  String? _hotelId;
  bool _saving = false;

  @override
  void dispose() {
    _rateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _selectHotel(String? id, List<AdminHotel> hotels) {
    final hotel = adminSelectedItem(hotels, id, (item) => item.id);
    setState(() {
      _hotelId = id;
      _rateController.text = hotel == null
          ? ''
          : (hotel.defaultCommissionRate * 100).toStringAsFixed(1);
      _noteController.clear();
    });
  }

  Future<void> _save(AdminHotel hotel) async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(platformAdminApiProvider).updateCommissionRate(
            hotelId: hotel.id,
            commissionRate: double.parse(_rateController.text) / 100,
          );
      ref.invalidate(adminHotelsProvider);
      if (!mounted) return;
      AppErrorPresenter.showSnackBar(context, 'Commission rate updated.');
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
    final hotels = ref.watch(adminHotelsProvider);
    return AdminRefreshView(
      onRefresh: () async => ref.invalidate(adminHotelsProvider),
      child: hotels.when(
        loading: () => const AdminLoadingBody(),
        error: (error, _) => AdminErrorBody(
          title: 'Unable to load commission settings',
          error: error,
          onRetry: () => ref.invalidate(adminHotelsProvider),
        ),
        data: (allHotels) {
          final approved = allHotels
              .where(
                (hotel) => hotel.approvalStatus.toLowerCase() == 'approved',
              )
              .toList(growable: false);
          final selected = adminSelectedItem(
            approved,
            _hotelId,
            (item) => item.id,
          );

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Hotel Selector',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: selected?.id,
                isExpanded: true,
                hint: const Text('Select an approved hotel'),
                items: approved
                    .map(
                      (hotel) => DropdownMenuItem(
                        value: hotel.id,
                        child: Text(
                          adminHotelName(hotel.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged:
                    _saving ? null : (value) => _selectHotel(value, approved),
              ),
              if (approved.isEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                const Text('No approved hotels are available.'),
              ],
              const SizedBox(height: AppSpacing.lg),
              _CurrentRateCard(rate: selected?.defaultCommissionRate),
              const SizedBox(height: AppSpacing.lg),
              Form(
                key: _formKey,
                child: _CommissionField(
                  controller: _rateController,
                  enabled: selected != null && !_saving,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _ImmediateEffectiveDate(),
              const SizedBox(height: AppSpacing.lg),
              AdminTextArea(
                label: 'Admin Note',
                controller: _noteController,
                enabled: false,
                hintText: 'Not supported by the current commission API',
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed:
                    selected == null || _saving ? null : () => _save(selected),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surface,
                        ),
                      )
                    : const Text('Save Rate'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CurrentRateCard extends StatelessWidget {
  const _CurrentRateCard({required this.rate});

  final double? rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.outlineSoft),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Current Commission Rate',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            rate == null ? '-' : adminPercent(rate!),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}

class _CommissionField extends StatelessWidget {
  const _CommissionField({
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Commission Rate',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d{0,2}(\.\d{0,2})?$'),
              ),
            ],
            decoration: const InputDecoration(
              hintText: '0',
              suffixText: '%',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            validator: (value) {
              final rate = double.tryParse(value ?? '');
              if (rate == null || rate < 0 || rate > 30) {
                return 'Enter a percentage from 0 to 30.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _ImmediateEffectiveDate extends StatelessWidget {
  const _ImmediateEffectiveDate();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Effective Date',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          const Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: AppColors.mutedInk,
              ),
              SizedBox(width: AppSpacing.sm),
              Text('Effective immediately'),
            ],
          ),
        ],
      ),
    );
  }
}
