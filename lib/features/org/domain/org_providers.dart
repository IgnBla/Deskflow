import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deskflow/core/providers/supabase_provider.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/features/auth/domain/auth_providers.dart';
import 'package:deskflow/features/org/data/org_repository.dart';
import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/org/domain/organization.dart';

part 'org_providers.g.dart';

final _log = AppLogger.getLogger('OrgProviders');

/// Holds the pre-loaded org ID from SharedPreferences (set in main.dart).
/// Defaults to `null` if no saved org exists.
final initialOrgIdProvider = Provider<String?>((_) => null);

@Riverpod(keepAlive: true)
OrgRepository orgRepository(Ref ref) {
  return OrgRepository(ref.watch(supabaseClientProvider));
}

@riverpod
Future<List<Organization>> userOrganizations(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(orgRepositoryProvider).getUserOrganizations(user.id);
}

@Riverpod(keepAlive: true)
class CurrentOrgId extends _$CurrentOrgId {
  /// SharedPreferences key — exposed for main.dart pre-warming.
  static const prefsKey = 'last_selected_org_id';

  @override
  String? build() {
    // Read the pre-loaded value synchronously (set in main.dart via override)
    final initial = ref.read(initialOrgIdProvider);
    if (initial != null) {
      _log.d('[FIX] CurrentOrgId: using pre-loaded org=$initial');
    }
    return initial;
  }

  void select(String orgId) {
    state = orgId;
    _persistToPrefs(orgId);
  }

  void clear() {
    state = null;
    _clearPrefs();
  }

  Future<void> _persistToPrefs(String orgId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, orgId);
      _log.d('[FIX] CurrentOrgId: persisted org=$orgId');
    } catch (e) {
      _log.d('[FIX] CurrentOrgId: could not persist org (non-critical): $e');
    }
  }

  Future<void> _clearPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKey);
      _log.d('[FIX] CurrentOrgId: cleared persisted org');
    } catch (e) {
      _log.d('[FIX] CurrentOrgId: could not clear org (non-critical): $e');
    }
  }
}

@riverpod
Future<OrgRole> currentUserRole(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  final orgId = ref.watch(currentOrgIdProvider);
  if (user == null || orgId == null) {
    return OrgRole.member; // Default fallback
  }
  return ref.read(orgRepositoryProvider).getRole(user.id, orgId);
}

@riverpod
bool isOwner(Ref ref) {
  final role = ref.watch(currentUserRoleProvider).valueOrNull;
  return role == OrgRole.owner;
}

@riverpod
bool isOwnerOrAdmin(Ref ref) {
  final role = ref.watch(currentUserRoleProvider).valueOrNull;
  return role == OrgRole.owner || role == OrgRole.admin;
}
