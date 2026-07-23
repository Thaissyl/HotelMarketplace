import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';

class SrsScreen extends StatelessWidget {
  const SrsScreen({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.actions,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.scrollable = true,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final Widget child;
  final Widget? leading;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  final bool scrollable;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: actions,
      ),
      body: SafeArea(
        child: scrollable
            ? SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: body,
              )
            : body,
      ),
    );
  }
}

class SrsFieldLabel extends StatelessWidget {
  const SrsFieldLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        label: required ? '$text, required' : text,
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class SrsSectionTitle extends StatelessWidget {
  const SrsSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class SrsPanel extends StatelessWidget {
  const SrsPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outlineSoft),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SrsSummaryRow extends StatelessWidget {
  const SrsSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final valueStyle = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: valueStyle),
          ),
        ],
      ),
    );
  }
}
