import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/widgets/work_primary_action_bar.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/admin/presentation/invite_user_screen.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/org/domain/organization.dart';

class _TestCurrentOrgId extends CurrentOrgId {
  _TestCurrentOrgId(this._value);

  final String? _value;

  @override
  String? build() => _value;
}

Widget buildApp() {
  return ProviderScope(
    overrides: [
      currentOrgIdProvider.overrideWith(() => _TestCurrentOrgId('org-1')),
      userOrganizationsProvider.overrideWith(
        (_) async => [
          Organization(
            id: 'org-1',
            name: 'Deskflow',
            inviteCode: 'DF-123',
            createdAt: DateTime(2026, 3, 31),
          ),
        ],
      ),
    ],
    child: const MaterialApp(home: InviteUserScreen()),
  );
}

void main() {
  testWidgets('uses work scaffold and sticky action for invite flow', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(WorkScreenScaffold), findsOneWidget);
    expect(find.byType(WorkPrimaryActionBar), findsOneWidget);
    expect(find.text('Отправить приглашение'), findsOneWidget);
  });

  testWidgets('uses adaptive desktop layout on wide widths', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite-user-desktop-layout')), findsOneWidget);
    expect(find.byKey(const Key('invite-user-main-column')), findsOneWidget);
    expect(find.byKey(const Key('invite-user-side-column')), findsOneWidget);
  });

  testWidgets('keeps email field as terminal submit field', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final fields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    expect(fields.single.textInputAction, TextInputAction.done);
  });
}
