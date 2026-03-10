import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Quiet scaffold for work-heavy screens.
///
/// Keeps the background restrained and allows an optional sticky bottom action
/// area for forms and task-driven screens.
class WorkScreenScaffold extends StatelessWidget {
  const WorkScreenScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomActionBar,
    this.floatingActionButton,
    this.padding,
    this.backgroundColor = DeskflowColors.workBackground,
    this.resizeToAvoidBottomInset = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomActionBar;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry? padding;
  final Color backgroundColor;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final content = padding == null
        ? body
        : Padding(padding: padding!, child: body);

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      body: SafeArea(
        bottom: bottomActionBar == null,
        child: content,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomActionBar == null
          ? null
          : SafeArea(top: false, child: bottomActionBar!),
    );
  }
}
