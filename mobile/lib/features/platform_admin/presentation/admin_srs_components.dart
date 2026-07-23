import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/app_shimmer.dart';

const int adminListPageSize = 3;
const int adminTablePageSize = 5;

class AdminRefreshView extends StatelessWidget {
  const AdminRefreshView({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: onRefresh, child: child);
  }
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outlineSoft),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const Divider(height: 1, color: AppColors.outlineSoft),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class AdminRecordList extends StatelessWidget {
  const AdminRecordList({
    required this.title,
    required this.rows,
    required this.emptyMessage,
    this.footer,
    super.key,
  });

  final String title;
  final List<Widget> rows;
  final String emptyMessage;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outlineSoft),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const Divider(height: 1, color: AppColors.outlineSoft),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedInk,
                    ),
              ),
            )
          else
            for (var index = 0; index < rows.length; index++) ...[
              rows[index],
              if (index < rows.length - 1)
                const Divider(height: 1, color: AppColors.outlineSoft),
            ],
          if (footer != null) ...[
            const Divider(height: 1, color: AppColors.outlineSoft),
            footer!,
          ],
        ],
      ),
    );
  }
}

class AdminRecordRow extends StatelessWidget {
  const AdminRecordRow({
    required this.title,
    required this.status,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.icon = Icons.description_rounded,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String status;
  final VoidCallback onTap;
  final bool selected;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surfaceSoft : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 92),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    border: Border.all(color: AppColors.outlineSoft),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(icon, color: AppColors.mutedInk, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.mutedInk,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AdminStatusBadge(status: status),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedInk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class AdminDetailRow extends StatelessWidget {
  const AdminDetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final bool showDivider;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: AppColors.mutedInk),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              SizedBox(
                width: icon == null ? 116 : 104,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedInk,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  value.trim().isEmpty ? 'Not recorded' : value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, color: AppColors.outlineSoft),
      ],
    );
  }
}

class AdminTextArea extends StatelessWidget {
  const AdminTextArea({
    required this.label,
    required this.controller,
    required this.enabled,
    this.hintText,
    this.maxLength = 500,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? hintText;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outlineSoft),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            enabled: enabled,
            minLines: 3,
            maxLines: 5,
            maxLength: maxLength,
            decoration: InputDecoration(
              hintText: hintText,
              counterText: '',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminPaginationBar extends StatelessWidget {
  const AdminPaginationBar({
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
    super.key,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous page',
            visualDensity: VisualDensity.compact,
            onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 72),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outlineSoft),
              borderRadius: BorderRadius.circular(AppRadii.xs),
            ),
            child: Text(
              '${page + 1} / $pageCount',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            visualDensity: VisualDensity.compact,
            onPressed:
                page + 1 < pageCount ? () => onPageChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class AdminLoadingBody extends StatelessWidget {
  const AdminLoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        AppShimmer(
          child: Column(
            children: [
              ShimmerBlock(width: double.infinity, height: 160),
              SizedBox(height: AppSpacing.md),
              ShimmerBlock(width: double.infinity, height: 220),
              SizedBox(height: AppSpacing.md),
              ShimmerBlock(width: double.infinity, height: 120),
            ],
          ),
        ),
      ],
    );
  }
}

class AdminErrorBody extends StatelessWidget {
  const AdminErrorBody({
    required this.title,
    required this.error,
    required this.onRetry,
    super.key,
  });

  final String title;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.section),
        const Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: AppColors.mutedInk,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppErrorPresenter.friendlyMessage(error),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}

class AdminSelectionHint extends StatelessWidget {
  const AdminSelectionHint(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedInk,
            ),
      ),
    );
  }
}

List<T> adminPage<T>(List<T> items, int page, int pageSize) {
  if (items.isEmpty) return <T>[];
  final start = page * pageSize;
  if (start >= items.length) return <T>[];
  final end = (start + pageSize).clamp(0, items.length);
  return items.sublist(start, end);
}

int adminPageCount(int itemCount, int pageSize) {
  if (itemCount == 0) return 1;
  return (itemCount / pageSize).ceil();
}

int adminValidPage(int page, int itemCount, int pageSize) {
  return page.clamp(0, adminPageCount(itemCount, pageSize) - 1);
}

T? adminSelectedItem<T>(
  List<T> items,
  String? selectedId,
  String Function(T item) idOf,
) {
  if (selectedId == null) return null;
  for (final item in items) {
    if (idOf(item) == selectedId) return item;
  }
  return null;
}

String adminHotelName(String value) {
  return value.trim().isEmpty ? 'Unnamed hotel' : value.trim();
}

String adminPercent(double value) {
  return '${(value * 100).toStringAsFixed(1)}%';
}

String adminShortId(String value) {
  final normalized = value.replaceAll('-', '').toUpperCase();
  return normalized.length <= 8 ? normalized : normalized.substring(0, 8);
}

String adminDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}
