import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:deskflow/core/widgets/work_primary_action_bar.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/customers/data/customer_repository.dart';
import 'package:deskflow/features/customers/domain/customer_providers.dart';
import 'package:deskflow/features/customers/presentation/customer_form_screen.dart';
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

  setUp(() {
    repository = _MockCustomerRepository();

    when(
      () => repository.createCustomer(
        orgId: any(named: 'orgId'),
        name: any(named: 'name'),
        phone: any(named: 'phone'),
        email: any(named: 'email'),
        address: any(named: 'address'),
        notes: any(named: 'notes'),
      ),
    ).thenAnswer(
      (_) async => Customer(
        id: 'customer-1',
        organizationId: 'org-1',
        name: 'Иван Иванов',
        createdAt: DateTime(2026, 3, 31),
      ),
    );
  });

  Widget buildApp() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CustomerFormScreen(),
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

  testWidgets('uses work scaffold and sticky action for customer form', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(WorkScreenScaffold), findsOneWidget);
    expect(find.byType(WorkPrimaryActionBar), findsOneWidget);
    expect(find.text('Создать клиента'), findsOneWidget);
  });

  testWidgets('uses adaptive desktop layout on wide widths', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-form-desktop-layout')), findsOneWidget);
    expect(find.byKey(const Key('customer-form-main-column')), findsOneWidget);
    expect(find.byKey(const Key('customer-form-side-column')), findsOneWidget);
  });

  testWidgets('customer summary keeps placeholder and updates live', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Без имени'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Иван');
    await tester.pump();

    expect(find.text('Иван'), findsWidgets);
    expect(find.text('Без имени'), findsNothing);
  });

  testWidgets('customer form fields declare next navigation order', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final fields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();

    expect(fields[0].textInputAction, TextInputAction.next);
    expect(fields[1].textInputAction, TextInputAction.next);
    expect(fields[2].textInputAction, TextInputAction.next);
    expect(fields[3].textInputAction, TextInputAction.next);
    expect(fields[4].textInputAction, TextInputAction.done);
  });
}
