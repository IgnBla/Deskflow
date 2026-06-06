import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/features/auth/data/auth_repository.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
}

@Riverpod(keepAlive: true)
Stream<AuthState> authStateChanges(Ref ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
}

@Riverpod(keepAlive: true)
User? currentUser(Ref ref) {
  final client = ref.watch(supabaseClientProvider);

  // Listen to auth changes but only rebuild on actual sign-in/sign-out,
  // NOT on token refresh (~every 55 min) which would cascade rebuilds
  // through the entire provider tree for no visible effect.
  ref.listen<AsyncValue<AuthState>>(authStateChangesProvider, (prev, next) {
    final event = next.valueOrNull?.event;
    if (event != null && event != AuthChangeEvent.tokenRefreshed) {
      ref.invalidateSelf();
    }
  });

  return client.auth.currentUser;
}

@riverpod
bool isAuthenticated(Ref ref) {
  return ref.watch(currentUserProvider) != null;
}


