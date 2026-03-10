import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Compact horizontal action/filter row for work screens.
class WorkFilterBar extends StatelessWidget {
  const WorkFilterBar({
    super.key,
    required this.children,
    this.padding,
    this.spacing = DeskflowSpacing.sm,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: children,
      ),
    );
  }
}
