import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/srs_screen.dart';
import 'login_screen.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.child,
    this.showBackButton = true,
  });

  final String title;
  final Widget child;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return SrsScreen(
      title: title,
      automaticallyImplyLeading: showBackButton,
      leading: showBackButton
          ? IconButton(
              tooltip: 'Back',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                context.go(LoginScreen.routePath);
              },
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.section,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: child,
    );
  }
}
