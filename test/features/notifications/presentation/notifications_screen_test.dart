import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/surface_card.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/notifications/domain/notification_model.dart';
import 'package:deskflow/features/notifications/domain/notification_providers.dart';
import 'package:deskflow/features/notifications/presentation/notifications_screen.dart';

class _TestNotificationsList extends NotificationsList {
  _TestNotificationsList(this.items);

  final List<AppNotification> items;

  @override
  Future<List<AppNotification>> build() async => items;
}

Widget buildApp(List<AppNotification> items) {
  return ProviderScope(
    overrides: [
      notificationsListProvider.overrideWith(() => _TestNotificationsList(items)),
    ],
    child: const MaterialApp(home: NotificationsScreen()),
  );
}

void main() {
  final notifications = [
    AppNotification(
      id: 'n1',
      orgId: 'org-1',
      userId: 'user-1',
      orderId: 'order-1',
      type: NotificationType.newOrder,
      title: 'Новый заказ #41',
      body: 'Клиент подтвердил доставку',
      createdAt: DateTime(2026, 3, 31),
    ),
    AppNotification(
      id: 'n2',
      orgId: 'org-1',
      userId: 'user-1',
      type: NotificationType.chatMessage,
      title: 'Новое сообщение',
      body: 'В чате появился ответ',
      isRead: true,
      createdAt: DateTime(2026, 3, 31),
    ),
  ];

  testWidgets('uses work scaffold and matte notification rows', (tester) async {
    await tester.pumpWidget(buildApp(notifications));
    await tester.pumpAndSettle();

    expect(find.byType(WorkScreenScaffold), findsOneWidget);
    expect(find.byType(SurfaceCard), findsNWidgets(2));
    expect(find.byType(GlassCard), findsNothing);
    expect(find.byKey(const Key('notification-row-0')), findsOneWidget);
    expect(find.byKey(const Key('notification-row-1')), findsOneWidget);
  });
}
