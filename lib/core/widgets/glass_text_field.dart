import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';

class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.suffixIcon,
    this.prefixIcon,
    this.inputFormatters,
    this.enabled = true,
    this.autofocus = false,
  });

  // ── Cached borders (avoid re-allocation on every build) ──
  static final _borderRadius = BorderRadius.circular(DeskflowRadius.md);

  static final _defaultBorder = OutlineInputBorder(
    borderRadius: _borderRadius,
    borderSide: const BorderSide(
      color: DeskflowColors.glassBorder,
      width: 0.5,
    ),
  );

  static final _focusedBorder = OutlineInputBorder(
    borderRadius: _borderRadius,
    borderSide: const BorderSide(
      color: DeskflowColors.primarySolid,
      width: 1,
    ),
  );

  static final _focusedErrorBorder = OutlineInputBorder(
    borderRadius: _borderRadius,
    borderSide: const BorderSide(
      color: DeskflowColors.destructiveSolid,
      width: 1,
    ),
  );

  static final _errorBorder = OutlineInputBorder(
    borderRadius: _borderRadius,
    borderSide: const BorderSide(
      color: DeskflowColors.destructiveSolid,
      width: 1,
    ),
  );

  static final _disabledBorder = OutlineInputBorder(
    borderRadius: _borderRadius,
    borderSide: BorderSide(
      color: DeskflowColors.glassBorder.withValues(alpha: 0.3),
      width: 0.5,
    ),
  );

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          enabled: enabled,
          autofocus: autofocus,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted ??
              (textInputAction == TextInputAction.next
                  ? (_) => FocusScope.of(context).nextFocus()
                  : null),
          style: DeskflowTypography.body,
          cursorColor: DeskflowColors.primarySolid,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            labelStyle: DeskflowTypography.bodySmall.copyWith(
              color: DeskflowColors.textSecondary,
            ),
            hintStyle: DeskflowTypography.body.copyWith(
              color: DeskflowColors.textTertiary,
            ),
            errorStyle: DeskflowTypography.caption.copyWith(
              color: DeskflowColors.destructiveSolid,
            ),
            filled: true,
            fillColor: DeskflowColors.glassSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DeskflowSpacing.lg,
              vertical: DeskflowSpacing.md,
            ),
            border: _defaultBorder,
            enabledBorder: _defaultBorder,
            focusedBorder: hasError ? _focusedErrorBorder : _focusedBorder,
            errorBorder: _errorBorder,
            focusedErrorBorder: _focusedErrorBorder,
            disabledBorder: _disabledBorder,
          ),
        ),
      ],
    );
  }
}
