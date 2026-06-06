import 'dart:async';

import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_notifier.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';
import 'package:deskflow/features/orders/domain/order_template.dart';
import 'package:deskflow/features/orders/domain/order_composition.dart';
import 'package:deskflow/features/orders/domain/order_item.dart';
import 'package:deskflow/features/orders/presentation/edit_order_screen.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_chip.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _FakeOrderNotifier extends OrderNotifier {
  int saveTemplateCallCount = 0;

  @override
  FutureOr<void> build() {}

  @override
  Future<OrderTemplate?> saveOrderTemplate({
    required String name,
    required OrderComposition composition,
    String? templateId,
  }) async {
    saveTemplateCallCount++;
    return OrderTemplate(
      id: 'tpl-1',
      organizationId: 'org-1',
      name: name,
      createdAt: DateTime(2026, 3, 10),
      updatedAt: DateTime(2026, 3, 10),
      composition: composition,
    );
  }
}

Order _sampleOrder() => Order(
  id: 'order-1',
  organizationId: 'org-1',
  customerId: 'cust-old',
  statusId: 'status-1',
  orderNumber: 41,
  totalAmount: 2800,
  deliveryCost: 200,
  notes: 'Комментарий',
  createdBy: 'user-1',
  createdAt: DateTime(2026, 3, 10),
  updatedAt: DateTime(2026, 3, 10),
  status: const OrderStatus(
    id: 'status-1',
    organizationId: 'org-1',
    name: 'Новый',
    color: '#3B82F6',
    sortOrder: 0,
    isDefault: true,
    isFinal: false,
  ),
  customerName: 'Старый клиент',
  items: [
    OrderItem(
      id: 'item-1',
      orderId: 'order-1',
      productId: 'prod-1',
      productName: 'Виджет А',
      unitPrice: 1400,
      quantity: 2,
    ),
  ],
);

Widget _buildSubject({
  _FakeOrderNotifier? notifier,
  List<Customer> recentCustomers = const [],
  List<Product> recentProducts = const [],
  List<OrderTemplate> templates = const [],
}) {
  return ProviderScope(
    overrides: [
      orderDetailProvider(
        'order-1',
      ).overrideWith((ref) async => _sampleOrder()),
      orderNotifierProvider.overrideWith(
        () => notifier ?? _FakeOrderNotifier(),
      ),
      recentOrderCustomersProvider.overrideWith((ref) async => recentCustomers),
      recentOrderProductsProvider.overrideWith((ref) async => recentProducts),
      orderTemplatesProvider.overrideWith((ref) async => templates),
    ],
    child: const MaterialApp(home: EditOrderScreen(orderId: 'order-1')),
  );
}

void main() {
  final recentCustomer = Customer(
    id: 'cust-new',
    organizationId: 'org-1',
    name: 'Новый клиент',
    createdAt: DateTime(2026, 3, 10),
  );
  final recentProduct = Product(
    id: 'prod-2',
    organizationId: 'org-1',
    name: 'Виджет B',
    price: 900,
    createdAt: DateTime(2026, 3, 10),
  );
  final template = OrderTemplate(
    id: 'tpl-1',
    organizationId: 'org-1',
    name: 'Повторный заказ',
    createdAt: DateTime(2026, 3, 10),
    updatedAt: DateTime(2026, 3, 10),
    composition: const OrderComposition(
      items: [
        OrderCompositionItem(
          productId: 'prod-1',
          productName: 'Виджет А',
          unitPrice: 1400,
          quantity: 2,
        ),
      ],
    ),
  );

  testWidgets('shows quick sources and template actions', (tester) async {
    await tester.pumpWidget(
      _buildSubject(
        recentCustomers: [recentCustomer],
        recentProducts: [recentProduct],
        templates: [template],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Быстрые источники'), findsOneWidget);
    expect(find.text('Шаблоны'), findsOneWidget);
    expect(find.text('Последние клиенты'), findsOneWidget);
    expect(find.text('Последние товары'), findsOneWidget);
    expect(find.text('Шаблон'), findsOneWidget);
    expect(find.text('Повторный заказ'), findsOneWidget);
    expect(find.text('Новый клиент'), findsOneWidget);
    expect(find.text('Виджет B'), findsOneWidget);
  });

  testWidgets('uses adaptive desktop layout and quiet quick sources on wide web', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSubject(
        recentCustomers: [recentCustomer],
        recentProducts: [recentProduct],
        templates: [template],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit-order-desktop-layout')), findsOneWidget);
    expect(find.byKey(const Key('edit-order-main-column')), findsOneWidget);
    expect(find.byKey(const Key('edit-order-side-column')), findsOneWidget);
    expect(find.byKey(const Key('quick-sources-panel')), findsOneWidget);
    expect(find.byType(GlassChip), findsNothing);
  });

  testWidgets('uses work screen scaffold with sticky save action', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    expect(find.byType(WorkScreenScaffold), findsOneWidget);
    expect(find.text('Сохранить заказ'), findsOneWidget);
  });

  testWidgets('recent customer chip updates selected customer', (tester) async {
    await tester.pumpWidget(_buildSubject(recentCustomers: [recentCustomer]));
    await tester.pumpAndSettle();

    expect(find.text('Клиент: Старый клиент'), findsOneWidget);

    await tester.tap(find.text('Новый клиент'));
    await tester.pumpAndSettle();

    expect(find.text('Клиент: Новый клиент'), findsOneWidget);
  });

  testWidgets('save template action saves current composition', (tester) async {
    final notifier = _FakeOrderNotifier();

    await tester.pumpWidget(_buildSubject(notifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Шаблон'));
    await tester.pumpAndSettle();

    expect(find.text('Новый шаблон'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Шаблон из заказа');
    await tester.tap(find.text('Сохранить шаблон'));
    await tester.pumpAndSettle();

    expect(notifier.saveTemplateCallCount, 1);
  });

  testWidgets('edit save-template dialog uses dense modal surface', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Шаблон'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, DeskflowColors.modalSurface);
  });

  testWidgets('template quick source confirms before leaving dirty edit form', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject(templates: [template]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Обновлённый комментарий');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('quick-source-template-row-0')));
    await tester.tap(find.byKey(const Key('quick-source-template-row-0')));
    await tester.pumpAndSettle();

    expect(find.text('Перейти к новому заказу?'), findsOneWidget);
    expect(
      find.text(
        'Несохранённые изменения в текущем заказе будут потеряны.',
      ),
      findsOneWidget,
    );
  });
}
