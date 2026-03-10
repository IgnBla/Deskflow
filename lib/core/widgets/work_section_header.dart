import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Compact section header for work screens.
class WorkSectionHeader extends StatelessWidget {
  const WorkSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.padding,
  });

  final String title;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ?? const EdgeInsets.symmetric(vertical: DeskflowSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: DeskflowTypography.h3.copyWith(
                fontSize: 18,
                color: DeskflowColors.textPrimary,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
