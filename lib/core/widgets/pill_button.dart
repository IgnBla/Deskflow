import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
    this.textColor,
    this.expanded = false,
    this.height = 48,
  });

  factory PillButton.primary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool expanded = false,
  }) {
    return PillButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      color: DeskflowColors.primary,
      expanded: expanded,
    );
  }

  factory PillButton.secondary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool expanded = false,
  }) {
    return PillButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      color: DeskflowColors.glassSurface,
      expanded: expanded,
    );
  }

  factory PillButton.destructive({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool expanded = false,
  }) {
    return PillButton(
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      color: DeskflowColors.destructive,
      expanded: expanded,
    );
  }

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? color;
  final Color? textColor;
  final bool expanded;
  final double height;

  bool get _isDisabled => (onPressed == null && !isLoading) || isLoading;

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? DeskflowColors.primary;
    final effectiveBg = _isDisabled && !isLoading
        ? bgColor.withValues(alpha: 0.3)
        : isLoading
            ? bgColor.withValues(alpha: 0.6)
            : bgColor;
    final effectiveTextColor = _isDisabled && !isLoading
        ? DeskflowColors.textDisabled
        : (textColor ?? DeskflowColors.textPrimary);

    final buttonChild = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: effectiveTextColor,
            ),
          ),
          const SizedBox(width: DeskflowSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: effectiveTextColor),
          const SizedBox(width: DeskflowSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            style: DeskflowTypography.button.copyWith(
              color: effectiveTextColor,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );

    return SizedBox(
      height: height,
      width: expanded ? double.infinity : null,
      child: MaterialButton(
        onPressed: isLoading ? null : onPressed,
        color: effectiveBg,
        disabledColor: effectiveBg,
        elevation: 0,
        highlightElevation: 0,
        shape: StadiumBorder(
          side: BorderSide(
            color: isLoading
                ? DeskflowColors.primarySolid.withValues(alpha: 0.3)
                : DeskflowColors.glassBorder,
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DeskflowSpacing.lg,
          vertical: DeskflowSpacing.sm,
        ),
        child: buttonChild,
      ),
    );
  }
}
