import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/widgets/work_primary_action_bar.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/admin/data/admin_repository.dart';
import 'package:deskflow/features/admin/domain/admin_providers.dart';
import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/org/domain/organization.dart';
import 'package:deskflow/features/profile/presentation/org_settings_screen.dart';

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
            createdAt: DateTime(2026, 3, 31),
          ),
        ],
      ),
      orgMembersProvider.overrideWith(
        (_) async => [
          MemberWithProfile(
            id: 'member-1',
            organizationId: 'org-1',
            userId: 'user-1',
            role: OrgRole.owner,
            joinedAt: DateTime(2026, 3, 31),
            fullName: 'Иван Петров',
            email: 'ivan@example.com',
          ),
        ],
      ),
    ],
    child: const MaterialApp(home: OrgSettingsScreen()),
  );
}

void main() {
  testWidgets('uses work scaffold and sticky action for org settings', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(WorkScreenScaffold), findsOneWidget);
    expect(find.byType(WorkPrimaryActionBar), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
    expect(find.text('1 участник'), findsOneWidget);
  });

  testWidgets('uses adaptive desktop layout on wide widths', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('org-settings-desktop-layout')), findsOneWidget);
    expect(find.byKey(const Key('org-settings-main-column')), findsOneWidget);
    expect(find.byKey(const Key('org-settings-side-column')), findsOneWidget);
  });
}
