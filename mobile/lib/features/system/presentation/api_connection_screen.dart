import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/app_error_presenter.dart';

final apiHealthProvider = FutureProvider.autoDispose<ApiHealthStatus>((ref) {
  return ref.watch(apiClientProvider).getHealthStatus();
});

class ApiConnectionScreen extends ConsumerWidget {
  const ApiConnectionScreen({super.key});

  static const String routeName = 'api-connection';
  static const String routePath = '/diagnostics';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);
    final health = ref.watch(apiHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel Marketplace'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Header(),
                    const SizedBox(height: AppSpacing.xl),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _EnvironmentRow(environment: environment),
                            const SizedBox(height: AppSpacing.xl),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: health.when(
                                data: (status) =>
                                    _HealthSuccess(status: status),
                                error: (error, stackTrace) =>
                                    _HealthFailure(error: error),
                                loading: () => const _HealthLoading(),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  ref.invalidate(apiHealthProvider);
                                },
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry connection'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: const Icon(
            Icons.wifi_tethering_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'API Connection',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'This screen verifies that the mobile app can reach the backend before feature screens are added.',
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _EnvironmentRow extends StatelessWidget {
  const _EnvironmentRow({required this.environment});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Environment',
          style: textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.outline),
          ),
          child: SelectableText(
            '${environment.flavor.name} | ${environment.apiBaseUrl}',
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _HealthLoading extends StatelessWidget {
  const _HealthLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: ValueKey('loading'),
      children: [
        SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: AppSpacing.sm),
        Text('Checking API status'),
      ],
    );
  }
}

class _HealthSuccess extends StatelessWidget {
  const _HealthSuccess({required this.status});

  final ApiHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded, color: colorScheme.tertiary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'API status: ${status.status}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        if (status.checks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          for (final check in status.checks)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '${check.name}: ${check.status} (${check.duration.toStringAsFixed(0)} ms)',
              ),
            ),
        ],
      ],
    );
  }
}

class _HealthFailure extends StatelessWidget {
  const _HealthFailure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = AppErrorPresenter.friendlyMessage(error);

    return Container(
      key: const ValueKey('failure'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
