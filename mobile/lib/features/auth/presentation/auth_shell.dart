import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import 'login_screen.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBackButton = true,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (showBackButton) ...[
              Align(
                alignment: Alignment.topLeft,
                child: IconButton.filledTonal(
                  tooltip: 'Back',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                      return;
                    }

                    context.go(LoginScreen.routePath);
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ] else
              const SizedBox(height: AppSpacing.xxl),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _AuthBrandMark(),
                    const SizedBox(height: AppSpacing.xl),
                    Text(title, style: textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.xxl),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: child,
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

class _AuthBrandMark extends StatelessWidget {
  const _AuthBrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141F4E79),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.bed_rounded,
        color: Colors.white,
      ),
    );
  }
}
