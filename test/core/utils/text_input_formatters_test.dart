import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/utils/text_input_formatters.dart';

void main() {
  test('formats grouped integer with spaces', () {
    final formatter = GroupedNumberTextInputFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: '1234567'),
    );

    expect(result.text, '1 234 567');
  });

  test('formats decimal number and keeps separator', () {
    final formatter = GroupedNumberTextInputFormatter(allowDecimal: true);
    final result = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: '1234567.8'),
    );

    expect(result.text, '1 234 567.8');
  });

  test('formats dotted date while typing', () {
    final formatter = DottedDateTextInputFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: '23092023'),
    );

    expect(result.text, '23.09.2023');
  });

  test('parses grouped number back to double', () {
    expect(parseFormattedNumber('12 345.50'), 12345.5);
  });
}
