import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/app_error_presenter.dart';
import '../../../shared/widgets/srs_screen.dart';
import '../domain/operations_models.dart';

class FrontDeskRouteScaffold extends StatelessWidget {
  const FrontDeskRouteScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: body,
          ),
        ),
      ),
    );
  }
}

class FrontDeskPanel extends StatelessWidget {
  const FrontDeskPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SrsPanel(padding: padding, child: child);
  }
}

class FrontDeskSectionTitle extends StatelessWidget {
  const FrontDeskSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class FrontDeskInfoRow extends StatelessWidget {
  const FrontDeskInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueAlign = TextAlign.right,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextAlign valueAlign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: valueAlign,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class FrontDeskStatusTag extends StatelessWidget {
  const FrontDeskStatusTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
      ),
    );
  }
}

class FrontDeskLoadingState extends StatelessWidget {
  const FrontDeskLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class FrontDeskErrorState extends StatelessWidget {
  const FrontDeskErrorState({
    super.key,
    required this.error,
    required this.onRetry,
    this.title = 'Unable to load this screen',
  });

  final Object error;
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: FrontDeskPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppErrorPresenter.friendlyMessage(error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FrontDeskEmptyState extends StatelessWidget {
  const FrontDeskEmptyState({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return FrontDeskPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 44),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class FrontDeskFieldLabel extends StatelessWidget {
  const FrontDeskFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

void showFrontDeskResult(
  BuildContext context,
  FrontDeskBookingResult result,
) {
  final invoiceText = result.invoiceId == null ? '' : ' Invoice generated.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          '${result.bookingCode} updated to ${result.status}.$invoiceText',
        ),
      ),
    );
}
