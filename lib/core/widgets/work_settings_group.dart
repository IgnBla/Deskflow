import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/surface_card.dart';
import 'package:deskflow/core/widgets/work_section_header.dart';

/// Grouped enterprise-style settings container for work screens.
class WorkSettingsGroup extends StatelessWidget {
  const WorkSettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.action,
    this.padding,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(
          const Divider(
            height: 1,
            thickness: 0.5,
            color: DeskflowColors.workDivider,
          ),
        );
      }
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WorkSectionHeader(title: title, action: action),
          SurfaceCard(
            variant: SurfaceCardVariant.primary,
            padding: EdgeInsets.zero,
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}
