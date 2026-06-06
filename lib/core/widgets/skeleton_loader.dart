import 'package:flutter/material.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

/// Wrap multiple [SkeletonLoader]s in a [SkeletonGroup] so they pulse
/// in perfect sync with a single shared [AnimationController].
///
/// Without a [SkeletonGroup] ancestor each loader creates its own
/// controller — they start at different times and produce a "popcorn"
/// shimmer effect. Always wrap list / grid skeleton placeholders:
///
/// ```dart
/// SkeletonGroup(
///   child: Column(
///     children: List.generate(5, (_) => SkeletonLoader(child: ...)),
///   ),
/// )
/// ```
class SkeletonGroup extends StatefulWidget {
  const SkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonGroup> createState() => _SkeletonGroupState();
}

class _SkeletonGroupState extends State<SkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonGroupScope(animation: _animation, child: widget.child);
  }
}

class _SkeletonGroupScope extends InheritedWidget {
  const _SkeletonGroupScope({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SkeletonGroupScope>()
        ?.animation;
  }

  @override
  bool updateShouldNotify(_SkeletonGroupScope oldWidget) =>
      animation != oldWidget.animation;
}

class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    required this.child,
  });

  final Widget child;

  static Widget box({
    double? width,
    double height = 16,
    double borderRadius = DeskflowRadius.md,
  }) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: DeskflowColors.glassSurface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  static Widget circle({double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: DeskflowColors.glassSurface,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  AnimationController? _ownController;
  Animation<double>? _effectiveAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final groupAnimation = _SkeletonGroupScope.maybeOf(context);
    if (groupAnimation != null) {
      // Shared group animation — dispose local controller if any.
      _ownController?.dispose();
      _ownController = null;
      _effectiveAnimation = groupAnimation;
    } else if (_ownController == null) {
      // No group — create a local fallback controller.
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat(reverse: true);
      _ownController = controller;
      _effectiveAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _effectiveAnimation!,
      child: widget.child,
    );
  }
}
