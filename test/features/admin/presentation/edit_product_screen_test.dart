import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:deskflow/core/widgets/work_primary_action_bar.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/admin/presentation/edit_product_screen.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/products/data/product_repository.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/products/domain/product_providers.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

class _TestCurrentOrgId extends CurrentOrgId {
  _TestCurrentOrgId(this._value);

  final String? _value;

  @override
  String? build() => _value;
}

void main() {
  late _MockProductRepository repository;

  setUp(() {
    repository = _MockProductRepository();

    when(
      () => repository.createProduct(
        orgId: any(named: 'orgId'),
        name: any(named: 'name'),
        price: any(named: 'price'),
        sku: any(named: 'sku'),
        description: any(named: 'description'),
        imageUrl: any(named: 'imageUrl'),
      ),
    ).thenAnswer(
      (_) async => Product(
        id: 'product-1',
        organizationId: 'org-1',
        name: 'Тестовый товар',
        price: 1000,
        createdAt: DateTime(2026, 3, 31),
      ),
    );
  });

  Widget buildApp() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const EditProductScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWith((ref) => repository),
        currentOrgIdProvider.overrideWith(() => _TestCurrentOrgId('org-1')),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('uses work scaffold and sticky action for product form', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(WorkScreenScaffold), findsOneWidget);
    expect(find.byType(WorkPrimaryActionBar), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
  });

  testWidgets('uses adaptive desktop layout on wide widths', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit-product-desktop-layout')), findsOneWidget);
    expect(find.byKey(const Key('edit-product-main-column')), findsOneWidget);
    expect(find.byKey(const Key('edit-product-side-column')), findsOneWidget);
  });

  testWidgets('product summary keeps placeholder and updates live', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Без названия'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Тестовый товар');
    await tester.pump();

    expect(find.text('Тестовый товар'), findsWidgets);
    expect(find.text('Без названия'), findsNothing);
  });

  testWidgets('product form fields declare next navigation order', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final fields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();

    expect(fields[0].textInputAction, TextInputAction.next);
    expect(fields[1].textInputAction, TextInputAction.next);
    expect(fields[2].textInputAction, TextInputAction.next);
    expect(fields[3].textInputAction, TextInputAction.done);
  });
}
