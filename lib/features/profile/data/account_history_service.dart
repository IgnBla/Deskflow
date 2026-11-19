import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deskflow/core/utils/app_logger.dart';

final _log = AppLogger.getLogger('AccountHistoryService');

class AccountHistoryService {
  static const _key = 'deskflow_recent_emails';
  static const _tokenKeyPrefix = 'deskflow_refresh_token_';
  static const int maxEmails = 5;

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  AccountHistoryService(
    this._prefs, {
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  List<String> getRecentEmails() {
    final emails = _prefs.getStringList(_key) ?? [];
    _log.d('getRecentEmails: count=${emails.length}');
    return emails;
  }

  Future<void> addEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      _log.d('addEmail: skipped — empty email');
      return;
    }

    final emails = getRecentEmails();
    _log.d('addEmail: before — count=${emails.length}');

    emails.remove(normalized);
    emails.insert(0, normalized);

    if (emails.length > maxEmails) {
      emails.removeRange(maxEmails, emails.length);
    }

    await _prefs.setStringList(_key, emails);
    _log.i('addEmail: after — count=${emails.length}');
  }

  Future<void> removeEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    final emails = getRecentEmails();
    _log.d('removeEmail: before — count=${emails.length}');

    emails.remove(normalized);
    await _prefs.setStringList(_key, emails);
    _log.i('removeEmail: after — count=${emails.length}');
  }


  Future<void> saveRefreshToken(String email, String refreshToken) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || refreshToken.isEmpty) {
      _log.d('saveRefreshToken: skipped — empty email or token');
      return;
    }
    final key = '$_tokenKeyPrefix$normalized';
    await _secureStorage.write(key: key, value: refreshToken);
    _log.i('saveRefreshToken: stored refresh token securely');
  }

  Future<String?> getRefreshToken(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final key = '$_tokenKeyPrefix$normalized';
    final token = await _secureStorage.read(key: key);
    _log.d('getRefreshToken: tokenPresent=${token != null}');
    return token;
  }

  Future<void> removeRefreshToken(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final key = '$_tokenKeyPrefix$normalized';
    await _secureStorage.delete(key: key);
    _log.d('removeRefreshToken: token removed');
  }

  Future<void> clear() async {
    _log.i('clear: removing all recent emails and tokens');
    final emails = getRecentEmails();
    for (final email in emails) {
      await removeRefreshToken(email);
    }
    await _prefs.remove(_key);
  }
}
