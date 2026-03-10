import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/customers/data/customer_repository.dart';
import 'package:deskflow/features/customers/domain/customer_providers.dart';
import 'package:deskflow/features/customers/presentation/customers_list_screen.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

class _MockCustomerRepository extends Mock implements CustomerRepository {}

class _TestCurrentOrgId extends CurrentOrgId {
  _TestCurrentOrgId(this._value);

  final String? _value;

  @override
  String? build() => _value;
}

void main() {
  late _MockCustomerRepository repository;

  final customer = Customer(
    id: 'customer-1',
    organizationId: 'org-1',
    name: 'Иван Иванов',
    phone: '+7 999 123-45-67',
    createdAt: DateTime(2026, 3, 31),
    orderCount: 4,
  );

  setUp(() {
    repository = _MockCustomerRepository();

    when(
      () => repository.getCustomers(
        orgId: 'org-1',
        search: any(named: 'search'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => [customer]);
  });

  Widget buildApp() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CustomersListScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        customerRepositoryProvider.overrideWith((ref) => repository),
        currentOrgIdProvider.overrideWith(() => _TestCurrentOrgId('org-1')),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('uses work shell and dense customer rows instead of glass cards', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(WorkScreenScaffold), findsOneWidget);
    expect(find.byKey(const Key('customer-row-customer-1')), findsOneWidget);
    expect(find.text('4 заказа'), findsOneWidget);
    expect(find.byType(GlassCard), findsNothing);
    expect(find.byIcon(Icons.person_add_rounded), findsOneWidget);
  });
}
