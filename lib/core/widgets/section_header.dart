import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Consistent section label for work screens.
///
/// Renders an uppercase-style muted label with optional trailing action.
/// Use to separate groups in lists, forms, and settings.
///
/// ```
/// ОРГАНИЗАЦИЯ                          [action]
/// ```
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.padding,
  });

  final String title;

  /// Optional trailing widget — usually a `TextButton` or icon button.
  final Widget? action;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            DeskflowSpacing.lg,
            DeskflowSpacing.xl,
            DeskflowSpacing.lg,
            DeskflowSpacing.sm,
          ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: DeskflowTypography.sectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
