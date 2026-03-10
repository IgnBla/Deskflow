import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';

void main() {
  testWidgets('uses quiet work surfaces and keeps sticky action visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDeskflowTheme(),
        home: const WorkScreenScaffold(
          body: Placeholder(),
          bottomActionBar: ColoredBox(
            key: Key('bottom-action'),
            color: DeskflowColors.workPrimaryAction,
            child: SizedBox(height: 72),
          ),
        ),
      ),
    );

    final scaffoldFinder = find.byType(WorkScreenScaffold);
    expect(scaffoldFinder, findsOneWidget);

    final scaffold = tester.widget<WorkScreenScaffold>(scaffoldFinder);
    expect(scaffold.backgroundColor, DeskflowColors.workBackground);
    expect(scaffold.backgroundColor, isNot(DeskflowColors.background));

    final bottomActionFinder = find.byKey(const Key('bottom-action'));
    expect(bottomActionFinder, findsOneWidget);

    final bottomActionRect = tester.getRect(bottomActionFinder);
    final scaffoldRect = tester.getRect(find.byType(Scaffold));

    expect(bottomActionRect.bottom, closeTo(scaffoldRect.bottom, 0.1));
  });
}
