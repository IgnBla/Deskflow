import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/solid_action_button.dart';
import 'package:deskflow/core/widgets/work_primary_action_bar.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/core/widgets/work_settings_group.dart';

void main() {
  testWidgets('renders sticky primary action content on work scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDeskflowTheme(),
        home: WorkScreenScaffold(
          body: const SizedBox.expand(),
          bottomActionBar: WorkPrimaryActionBar(
            summary: const Text('3 товара · 24 923 ₽'),
            label: 'Сохранить заказ',
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('3 товара · 24 923 ₽'), findsOneWidget);
    expect(find.text('Сохранить заказ'), findsOneWidget);

    final actionRect = tester.getRect(find.byType(WorkPrimaryActionBar));
    final scaffoldRect = tester.getRect(find.byType(Scaffold));
    expect(actionRect.bottom, closeTo(scaffoldRect.bottom, 0.1));
  });

  testWidgets('renders grouped settings rows without oversized cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDeskflowTheme(),
        home: Scaffold(
          body: WorkSettingsGroup(
            title: 'Аккаунт',
            children: const <Widget>[
              ListTile(title: Text('Сменить аккаунт')),
              ListTile(title: Text('Выйти')),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Аккаунт'), findsOneWidget);
    expect(find.text('Сменить аккаунт'), findsOneWidget);
    expect(find.text('Выйти'), findsOneWidget);
  });

  testWidgets('stacks summary and action vertically on narrow widths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDeskflowTheme(),
        home: WorkScreenScaffold(
          body: const SizedBox.expand(),
          bottomActionBar: WorkPrimaryActionBar(
            summary: const Text('3 товара · 24 923 ₽'),
            label: 'Сохранить заказ',
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final summaryRect = tester.getRect(find.text('3 товара · 24 923 ₽'));
    final buttonRect = tester.getRect(find.text('Сохранить заказ'));
    expect(summaryRect.top, lessThan(buttonRect.top));
  });

  testWidgets('keeps compact action bar height bounded on mobile widths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDeskflowTheme(),
        home: WorkScreenScaffold(
          body: const SizedBox.expand(),
          bottomActionBar: WorkPrimaryActionBar(
            summary: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Итого'),
                SizedBox(height: 4),
                Text('0 ₽'),
              ],
            ),
            label: 'Сохранить заказ',
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final actionRect = tester.getRect(find.byType(WorkPrimaryActionBar));
    expect(actionRect.height, lessThan(220));
  });

  testWidgets('pins primary action to the right edge on wide widths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDeskflowTheme(),
        home: WorkScreenScaffold(
          body: const SizedBox.expand(),
          bottomActionBar: WorkPrimaryActionBar(
            summary: const Text('Итого · 24 923 ₽'),
            label: 'Сохранить заказ',
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final actionBarRect = tester.getRect(find.byType(WorkPrimaryActionBar));
    final buttonRect = tester.getRect(find.byType(SolidActionButton));

    expect(actionBarRect.right - buttonRect.right, lessThanOrEqualTo(56));
  });
}
