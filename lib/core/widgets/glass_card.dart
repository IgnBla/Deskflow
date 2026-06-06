import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.borderColor,
    this.blurSigma = 24,
    this.elevated = false,
    this.enableBlur = true,
  });

  final Widget child;

  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  final EdgeInsetsGeometry? padding;

  final EdgeInsetsGeometry? margin;

  final double? borderRadius;

  final Color? color;

  final Color? borderColor;

  final double blurSigma;

  final bool elevated;

  /// When `false`, skips the expensive [BackdropFilter] blur.
  /// Use `false` for cards rendered inside lists/grids to avoid GPU overdraw.
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? DeskflowRadius.card;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final surfaceColor = color ??
        (elevated
            ? DeskflowColors.glassSurfaceElevated
            : DeskflowColors.glassSurface);
    final glowColor = elevated
        ? DeskflowColors.glassGlow.withValues(alpha: 0.12)
        : DeskflowColors.glassGlow.withValues(alpha: 0.05);

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ??
            (elevated
                ? DeskflowColors.glassBorderStrong.withValues(alpha: 0.78)
                : DeskflowColors.glassBorderStrong.withValues(alpha: 0.52)),
        width: elevated ? 0.9 : 0.75,
      ),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.alphaBlend(
            DeskflowColors.glassHighlight.withValues(
              alpha: elevated ? 0.12 : 0.06,
            ),
            surfaceColor,
          ),
          Color.alphaBlend(glowColor, surfaceColor),
          surfaceColor,
        ],
        stops: const [0.0, 0.18, 1.0],
      ),
      boxShadow: [
        BoxShadow(
          color: glowColor,
          blurRadius: elevated ? 22 : 14,
          spreadRadius: elevated ? 1 : 0,
          offset: const Offset(0, 8),
        ),
      ],
    );

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: shape,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(DeskflowSpacing.lg),
          child: child,
        ),
      ),
    );

    return Container(
      margin: margin,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: enableBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: elevated ? blurSigma + 8 : blurSigma,
                    sigmaY: elevated ? blurSigma + 8 : blurSigma,
                  ),
                  child: DecoratedBox(
                    decoration: decoration,
                    child: content,
                  ),
                )
              : DecoratedBox(
                  decoration: decoration,
                  child: content,
                ),
        ),
      ),
    );
  }
}
