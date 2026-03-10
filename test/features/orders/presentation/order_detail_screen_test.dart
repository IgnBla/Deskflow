import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/work_primary_action_bar.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/chat/domain/chat_message.dart';
import 'package:deskflow/features/chat/domain/chat_providers.dart';
import 'package:deskflow/features/orders/data/order_repository.dart';
import 'package:deskflow/features/orders/domain/audit_event.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_item.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';
import 'package:deskflow/features/orders/presentation/order_detail_screen.dart';

class _MockOrderRepository extends Mock implements OrderRepository {}

Order _sampleOrder() => Order(
  id: 'order-1',
  organizationId: 'org-1',
  customerId: 'customer-1',
  statusId: 'status-1',
  orderNumber: 42,
  totalAmount: 2800,
  deliveryCost: 300,
  notes: 'Доставить до 18:00',
  createdBy: 'user-1',
  createdAt: DateTime(2026, 3, 31, 10, 30),
  updatedAt: DateTime(2026, 3, 31, 10, 30),
  customerName: 'Иван Иванов',
  status: const OrderStatus(
    id: 'status-1',
    organizationId: 'org-1',
    name: 'Новый',
    color: '#3B82F6',
    sortOrder: 0,
    isDefault: true,
    isFinal: false,
  ),
  items: const [
    OrderItem(
      id: 'item-1',
      orderId: 'order-1',
      productId: 'product-1',
      productName: 'Виджет A',
      unitPrice: 1400,
      quantity: 2,
    ),
  ],
);

Widget _buildSubject() {
  final repository = _MockOrderRepository();
  when(() => repository.getOrderAuditLog('order-1')).thenAnswer(
    (_) async => [
      AuditEvent(
        id: 'audit-1',
        organizationId: 'org-1',
        entityType: 'order',
        entityId: 'order-1',
        action: 'status_changed',
        newValue: const {'status': 'Новый'},
        userId: 'user-1',
        userName: 'Иван Петров',
        createdAt: DateTime(2026, 3, 31, 11, 0),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      orderRepositoryProvider.overrideWith((ref) => repository),
      orderDetailProvider('order-1').overrideWith((ref) async => _sampleOrder()),
      chatPreviewProvider('order-1').overrideWith(
        (ref) async => [
          ChatMessage(
            id: 'msg-1',
            orderId: 'order-1',
            senderId: 'user-2',
            senderName: 'Мария',
            text: 'Курьер уже в пути',
            createdAt: DateTime(2026, 3, 31, 11, 15),
          ),
        ],
      ),
      chatMessageCountProvider('order-1').overrideWith((ref) async => 5),
    ],
    child: const MaterialApp(home: OrderDetailScreen(orderId: 'order-1')),
  );
}

void main() {
  testWidgets('uses work shell with stronger header and action bar', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    expect(find.byType(WorkScreenScaffold), findsOneWidget);
    expect(find.byKey(const Key('order-detail-header')), findsOneWidget);
    expect(find.byKey(const Key('order-item-row-item-1')), findsOneWidget);
    expect(find.byType(WorkPrimaryActionBar), findsOneWidget);
    expect(find.text('Итого'), findsOneWidget);
    expect(find.byType(GlassCard), findsNothing);
  });

  testWidgets('stays overflow-safe on narrow widths', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    expect(find.byType(WorkPrimaryActionBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
