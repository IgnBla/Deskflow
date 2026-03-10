import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/features/auth/presentation/register_screen.dart';

void main() {
  testWidgets('uses shared auth shell', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-shell')), findsOneWidget);
    expect(find.text('Создать аккаунт'), findsWidgets);
  });
}
