import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/solid_action_button.dart';
import 'package:deskflow/core/widgets/surface_card.dart';

/// Sticky bottom summary + primary CTA for work flows.
class WorkPrimaryActionBar extends StatelessWidget {
  const WorkPrimaryActionBar({
    super.key,
    required this.summary,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.padding,
  });

  final Widget summary;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DeskflowColors.workBackground,
      child: Padding(
        padding: padding ??
            const EdgeInsets.fromLTRB(
              DeskflowSpacing.lg,
              DeskflowSpacing.sm,
              DeskflowSpacing.lg,
              DeskflowSpacing.lg,
            ),
        child: SurfaceCard(
          variant: SurfaceCardVariant.elevated,
          padding: const EdgeInsets.all(DeskflowSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 460;
              final isExpanded = constraints.maxWidth >= 840;

              if (isCompact) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    summary,
                    const SizedBox(height: DeskflowSpacing.md),
                    SolidActionButton(
                      label: label,
                      onPressed: onPressed,
                      isLoading: isLoading,
                      color: DeskflowColors.workPrimaryAction,
                    ),
                  ],
                );
              }

              if (isExpanded) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(child: summary),
                    const SizedBox(width: DeskflowSpacing.xl),
                    SizedBox(
                      width: 280,
                      child: SolidActionButton(
                        label: label,
                        onPressed: onPressed,
                        isLoading: isLoading,
                        color: DeskflowColors.workPrimaryAction,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: summary),
                  const SizedBox(width: DeskflowSpacing.lg),
                  Flexible(
                    child: SolidActionButton(
                      label: label,
                      onPressed: onPressed,
                      isLoading: isLoading,
                      color: DeskflowColors.workPrimaryAction,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
