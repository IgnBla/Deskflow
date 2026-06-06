import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Dense row-based entity tile for work screens.
///
/// Replaces tall glass cards in lists with a compact, data-first layout:
/// ```
/// [leading]  title                    [trailing]
///            subtitle     [badge]
/// ```
///
/// Used for orders, customers, products, pipeline statuses, settings items.
class WorkListTile extends StatelessWidget {
  const WorkListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.badge,
    this.onTap,
    this.onLongPress,
    this.contentPadding,
    this.showDivider = true,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Small inline badge (status, count, etc.) shown after subtitle.
  final Widget? badge;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? contentPadding;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            splashFactory: NoSplash.splashFactory,
            highlightColor: DeskflowColors.workSurfaceHover.withValues(
              alpha: 0.4,
            ),
            borderRadius: BorderRadius.circular(DeskflowRadius.workTile),
            child: Padding(
              padding:
                  contentPadding ??
                  const EdgeInsets.symmetric(
                    horizontal: DeskflowSpacing.lg,
                    vertical: DeskflowSpacing.md,
                  ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: DeskflowSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DefaultTextStyle.merge(
                          style: DeskflowTypography.body,
                          child: title,
                        ),
                        if (subtitle != null || badge != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: DeskflowSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                if (subtitle != null)
                                  Flexible(
                                    child: DefaultTextStyle.merge(
                                      style: DeskflowTypography.meta,
                                      child: subtitle!,
                                    ),
                                  ),
                                if (badge != null) ...[
                                  const SizedBox(width: DeskflowSpacing.sm),
                                  badge!,
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: DeskflowSpacing.md),
                    DefaultTextStyle.merge(
                      style: DeskflowTypography.bodyMono,
                      child: trailing!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: DeskflowColors.workDivider,
            indent: leading != null ? 52 : DeskflowSpacing.lg,
            endIndent: DeskflowSpacing.lg,
          ),
      ],
    );
  }
}
