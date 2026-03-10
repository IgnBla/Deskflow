import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/admin/presentation/catalog_management_screen.dart';
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

  final product = Product(
    id: 'product-1',
    organizationId: 'org-1',
    name: 'Виджет Pro',
    price: 2500,
    sku: 'SKU-001',
    createdAt: DateTime(2026, 3, 31),
  );

  setUp(() {
    repository = _MockProductRepository();
    when(
      () => repository.getProducts(
        orgId: 'org-1',
        search: any(named: 'search'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => [product]);
  });

  Widget buildApp() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CatalogManagementScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        currentOrgIdProvider.overrideWith(() => _TestCurrentOrgId('org-1')),
        productRepositoryProvider.overrideWith((ref) => repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('uses work shell and inventory rows instead of glass cards', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(WorkScreenScaffold), findsOneWidget);
    expect(find.byKey(const Key('catalog-product-row-product-1')), findsOneWidget);
    expect(find.text('SKU-001'), findsOneWidget);
    expect(find.byType(GlassCard), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
