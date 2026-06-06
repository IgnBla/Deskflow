import 'package:flutter/services.dart';

class GroupedNumberTextInputFormatter extends TextInputFormatter {
  GroupedNumberTextInputFormatter({
    this.allowDecimal = false,
    this.maxDecimalDigits = 2,
  });

  final bool allowDecimal;
  final int maxDecimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = newValue.text.replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) {
      return const TextEditingValue();
    }

    final buffer = StringBuffer();
    var hasSeparator = false;

    for (final char in normalized.split('')) {
      if (_isDigit(char)) {
        buffer.write(char);
        continue;
      }
      if (allowDecimal && char == '.' && !hasSeparator) {
        hasSeparator = true;
        buffer.write(char);
      }
    }

    var sanitized = buffer.toString();
    if (!allowDecimal) {
      sanitized = sanitized.replaceAll('.', '');
    }

    final hadTrailingSeparator =
        allowDecimal && sanitized.isNotEmpty && sanitized.endsWith('.');
    final parts = sanitized.split('.');
    final integerPart = _groupDigits(parts.first);
    final decimalPart = allowDecimal && parts.length > 1
        ? parts[1].substring(0, parts[1].length.clamp(0, maxDecimalDigits))
        : '';

    final formatted = StringBuffer(integerPart);
    if (allowDecimal && (hadTrailingSeparator || decimalPart.isNotEmpty)) {
      formatted.write('.');
      formatted.write(decimalPart);
    }

    final text = formatted.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  bool _isDigit(String char) => char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

  String _groupDigits(String digits) {
    if (digits.isEmpty) return '';
    final normalized = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final source = normalized.isEmpty ? '0' : normalized;
    final reversed = source.split('').reversed.toList();
    final grouped = <String>[];
    for (var i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) {
        grouped.add(' ');
      }
      grouped.add(reversed[i]);
    }
    return grouped.reversed.join();
  }
}

class DottedDateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final clamped = digits.substring(0, digits.length.clamp(0, 8));
    final buffer = StringBuffer();

    for (var i = 0; i < clamped.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('.');
      }
      buffer.write(clamped[i]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

double? parseFormattedNumber(String value) {
  final normalized = value.replaceAll(' ', '').replaceAll(',', '.').trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

int? parseFormattedInt(String value) {
  final normalized = value.replaceAll(RegExp(r'[^\d]'), '').trim();
  if (normalized.isEmpty) return null;
  return int.tryParse(normalized);
}
