import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/org/domain/organization.dart';
import 'package:deskflow/features/org/presentation/org_selection_screen.dart';

void main() {
  testWidgets('uses shared auth shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userOrganizationsProvider.overrideWith(
            (ref) async => [
              Organization(
                id: 'org-1',
                name: 'Deskflow',
                createdAt: DateTime(2026, 3, 31),
                userRole: 'owner',
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: OrgSelectionScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-shell')), findsOneWidget);
    expect(find.text('Выберите организацию'), findsOneWidget);
  });
}
