import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

class DeskflowShellBackground extends StatelessWidget {
  const DeskflowShellBackground({
    super.key,
    this.image = const AssetImage(
      'assets/backgrounds/shell_liquid_purple_bg.png',
    ),
    this.dimmed = false,
  });

  final ImageProvider image;

  /// When true, applies a heavier scrim — use on data-heavy work screens
  /// to make content dominate over the decorative background.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final scrimColors =
        dimmed
            ? [
              Colors.black.withValues(alpha: 0.78),
              Colors.black.withValues(alpha: 0.72),
              Colors.black.withValues(alpha: 0.82),
            ]
            : [
              Colors.black.withValues(alpha: 0.45),
              Colors.black.withValues(alpha: 0.35),
              Colors.black.withValues(alpha: 0.55),
            ];

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: DeskflowColors.background,
              image: DecorationImage(
                image: image,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: scrimColors,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
