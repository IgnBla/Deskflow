import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/admin/data/admin_repository.dart';
import 'package:deskflow/features/admin/domain/admin_providers.dart';
import 'package:deskflow/features/admin/presentation/pipeline_config_screen.dart';
import 'package:deskflow/features/orders/domain/order_status.dart';

class _MockAdminRepository extends Mock implements AdminRepository {}

void main() {
  late _MockAdminRepository repository;

  const statuses = [
    OrderStatus(
      id: 'status-1',
      organizationId: 'org-1',
      name: 'Новый',
      color: '#3B82F6',
      sortOrder: 0,
      isDefault: true,
      isFinal: false,
    ),
    OrderStatus(
      id: 'status-2',
      organizationId: 'org-1',
      name: 'Доставлен',
      color: '#10B981',
      sortOrder: 1,
      isDefault: false,
      isFinal: true,
    ),
  ];

  setUp(() {
    repository = _MockAdminRepository();
    when(() => repository.reorderStatuses(any())).thenAnswer((_) async {});
    when(() => repository.countOrdersWithStatus(any())).thenAnswer((_) async => 0);
    when(() => repository.deleteStatus(any())).thenAnswer((_) async {});
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        adminRepositoryProvider.overrideWith((ref) => repository),
        adminPipelineProvider.overrideWith((ref) async => statuses),
      ],
      child: const MaterialApp(home: PipelineConfigScreen()),
    );
  }

  testWidgets('uses work shell and compact status rows instead of glass cards', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(WorkScreenScaffold), findsOneWidget);
    expect(find.byKey(const Key('pipeline-status-row-status-1')), findsOneWidget);
    expect(find.byKey(const Key('pipeline-status-row-status-2')), findsOneWidget);
    expect(find.text('По умолчанию'), findsOneWidget);
    expect(find.text('Финальный'), findsOneWidget);
    expect(find.byType(GlassCard), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
