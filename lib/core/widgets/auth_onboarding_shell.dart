import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/deskflow_shell_background.dart';

/// Shared premium shell for auth and onboarding screens.
class AuthOnboardingShell extends StatelessWidget {
  const AuthOnboardingShell({
    super.key,
    required this.child,
    this.appBar,
    this.padding,
    this.maxWidth = 520,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DeskflowShellBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                key: const Key('auth-shell'),
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding:
                      padding ?? const EdgeInsets.all(DeskflowSpacing.xl),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
