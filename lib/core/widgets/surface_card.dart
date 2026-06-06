import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Matte surface card for work screens — no blur, no glass effects.
///
/// Use instead of [GlassCard] on data-heavy screens (orders, customers,
/// catalog, settings, search results). Provides a quiet, dense container
/// that lets content dominate over decoration.
///
/// Three visual variants via [SurfaceCardVariant]:
/// - [primary]  — default elevated surface
/// - [flat]     — minimal, flush with background (for inline groups)
/// - [elevated] — prominent, for hero sections / sticky headers
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.borderRadius,
    this.variant = SurfaceCardVariant.primary,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final SurfaceCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? DeskflowRadius.workCard;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    final (bgColor, borderColor, borderWidth) = switch (variant) {
      SurfaceCardVariant.primary => (
          DeskflowColors.workSurface,
          DeskflowColors.workBorder,
          0.5,
        ),
      SurfaceCardVariant.flat => (
          Colors.transparent,
          DeskflowColors.workBorderSubtle,
          0.5,
        ),
      SurfaceCardVariant.elevated => (
          DeskflowColors.workSurfaceElevated,
          DeskflowColors.workBorder,
          0.75,
        ),
    };

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          customBorder: shape,
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: DeskflowColors.workSurfaceHover.withValues(
            alpha: 0.5,
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(DeskflowSpacing.lg),
            child: child,
          ),
        ),
      ),
    );
  }
}

enum SurfaceCardVariant {
  /// Default work surface — subtle border, opaque background.
  primary,

  /// Transparent background — for inline groups, no visual separation.
  flat,

  /// Elevated surface — brighter, for hero sections and sticky headers.
  elevated,
}
