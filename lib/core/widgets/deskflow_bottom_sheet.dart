import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Unified modal bottom sheet for Deskflow work screens.
///
/// Provides a consistent container for all sheets: filters, pickers,
/// confirmations, action menus. Uses matte surfaces, not glass.
///
/// Anatomy:
/// ```
/// ┌─ handle bar ─┐
/// │  title    [X] │
/// │               │
/// │   content     │
/// │               │
/// └───────────────┘
/// ```
class DeskflowBottomSheet extends StatelessWidget {
  const DeskflowBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
    this.showCloseButton = false,
    this.maxHeightFraction = 0.85,
    this.padding,
  });

  final Widget child;
  final String? title;
  final bool showHandle;
  final bool showCloseButton;
  final double maxHeightFraction;
  final EdgeInsetsGeometry? padding;

  /// Show this sheet as a modal bottom sheet with unified styling.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      barrierColor: DeskflowColors.modalBackdrop,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final maxHeight =
        MediaQuery.sizeOf(context).height * maxHeightFraction;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: DeskflowColors.workSurfaceElevated,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DeskflowRadius.workSheet),
          ),
          border: Border(
            top: BorderSide(
              color: DeskflowColors.workBorder,
              width: 0.5,
            ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle) _buildHandle(),
              if (title != null || showCloseButton) _buildHeader(context),
              Flexible(
                child: Padding(
                  padding:
                      padding ??
                      EdgeInsets.fromLTRB(
                        DeskflowSpacing.lg,
                        0,
                        DeskflowSpacing.lg,
                        DeskflowSpacing.lg + bottomSafe,
                      ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: DeskflowSpacing.sm),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: DeskflowColors.workBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DeskflowSpacing.lg,
        DeskflowSpacing.md,
        DeskflowSpacing.sm,
        DeskflowSpacing.sm,
      ),
      child: Row(
        children: [
          if (title != null)
            Expanded(
              child: Text(
                title!,
                style: DeskflowTypography.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (showCloseButton)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.close_rounded,
                size: 22,
                color: DeskflowColors.textSecondary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
            ),
        ],
      ),
    );
  }
}
