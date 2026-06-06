import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';

void main() {
  testWidgets('moves focus to the next field on next action by default', (
    tester,
  ) async {
    final firstFocusNode = FocusNode();
    final secondFocusNode = FocusNode();
    addTearDown(firstFocusNode.dispose);
    addTearDown(secondFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDeskflowTheme(),
        home: Scaffold(
          body: Column(
            children: [
              GlassTextField(
                label: 'Первое поле',
                focusNode: firstFocusNode,
                textInputAction: TextInputAction.next,
              ),
              GlassTextField(
                label: 'Второе поле',
                focusNode: secondFocusNode,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
      ),
    );

    firstFocusNode.requestFocus();
    await tester.pump();

    final firstField = tester.widget<EditableText>(find.byType(EditableText).first);
    firstField.onSubmitted?.call('test');
    await tester.pump();

    expect(secondFocusNode.hasFocus, isTrue);
  });
}
