import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/core/widgets/work_settings_group.dart';
import 'package:deskflow/features/profile/domain/notification_settings.dart';
import 'package:deskflow/features/profile/domain/profile_providers.dart';
import 'package:deskflow/features/profile/presentation/notification_settings_screen.dart';

class _TestNotificationSettingsNotifier extends NotificationSettingsNotifier {
  @override
  Future<NotificationSettings> build() async {
    return const NotificationSettings(
      userId: 'user-1',
      organizationId: 'org-1',
    );
  }
}

Widget buildApp() {
  return ProviderScope(
    overrides: [
      notificationSettingsNotifierProvider.overrideWith(
        () => _TestNotificationSettingsNotifier(),
      ),
    ],
    child: const MaterialApp(home: NotificationSettingsScreen()),
  );
}

void main() {
  testWidgets('uses work scaffold and grouped settings surface', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(WorkScreenScaffold), findsOneWidget);
    expect(find.byType(WorkSettingsGroup), findsOneWidget);
    expect(find.text('Новые заказы'), findsOneWidget);
    expect(find.text('Звук уведомлений'), findsOneWidget);
  });
}
