import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Confident, opaque primary CTA button — replaces glass FAB.
///
/// Use as the single primary action on a work screen. Can be used as:
/// - A full-width bottom bar action (`expanded: true`)
/// - An inline action button (`expanded: false`)
/// - A floating action button via `SolidActionButton.fab()`
///
/// No backdrop blur, no glass gradients. Solid, readable, trustworthy.
class SolidActionButton extends StatelessWidget {
  const SolidActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.height = 48,
    this.color,
  });

  /// Compact FAB-style variant with icon only.
  const SolidActionButton.fab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.color,
  })  : label = '',
        expanded = false,
        height = 56;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;
  final double height;
  final Color? color;

  bool get _isFab => label.isEmpty && icon != null;
  bool get _isDisabled => onPressed == null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? DeskflowColors.primarySolid;
    final effectiveBg =
        _isDisabled
            ? baseColor.withValues(alpha: 0.3)
            : isLoading
            ? baseColor.withValues(alpha: 0.7)
            : baseColor;
    const textColor = DeskflowColors.backgroundBase;

    if (_isFab) {
      return _buildFab(effectiveBg, textColor);
    }

    return _buildButton(effectiveBg, textColor);
  }

  Widget _buildFab(Color bg, Color fg) {
    return SizedBox(
      width: height,
      height: height,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child:
                isLoading
                    ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: fg,
                      ),
                    )
                    : Icon(icon, size: 24, color: fg),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(Color bg, Color fg) {
    return SizedBox(
      height: height,
      width: expanded ? double.infinity : null,
      child: MaterialButton(
        onPressed: isLoading ? null : onPressed,
        color: bg,
        disabledColor: bg,
        elevation: 0,
        highlightElevation: 0,
        shape: StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: DeskflowSpacing.xl,
          vertical: DeskflowSpacing.sm,
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: fg,
                ),
              ),
              const SizedBox(width: DeskflowSpacing.sm),
            ] else if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: DeskflowSpacing.sm),
            ],
            if (label.isNotEmpty)
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: DeskflowTypography.button.copyWith(
                    color: fg,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sticky bottom action bar — wraps a primary CTA with safe area padding.
///
/// Typical usage at the bottom of a form or detail screen:
/// ```dart
/// bottomNavigationBar: BottomActionBar(
///   child: SolidActionButton(
///     label: 'Сохранить',
///     expanded: true,
///     onPressed: () => ...,
///   ),
/// ),
/// ```
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            DeskflowSpacing.lg,
            DeskflowSpacing.md,
            DeskflowSpacing.lg,
            DeskflowSpacing.md + bottomSafe,
          ),
      decoration: const BoxDecoration(
        color: DeskflowColors.backgroundBase,
        border: Border(
          top: BorderSide(color: DeskflowColors.workBorder, width: 0.5),
        ),
      ),
      child: child,
    );
  }
}
