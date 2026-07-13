import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/auth/auth_token_store.dart';
import 'package:yalla_home/core/auth/browser_session_storage_base.dart';
import 'package:yalla_home/core/auth/session_metadata.dart';

void main() {
  final now = DateTime.utc(2030, 1, 1, 12);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('parses backend-authoritative temporary session metadata', () {
    final tokens = tokensFromApiPayload(_payload(now, remembered: false));

    expect(tokens.mode, AuthSessionMode.temporary);
    expect(tokens.isRemembered, isFalse);
    expect(tokens.sessionStartedAt, now);
    expect(tokens.absoluteExpiresAt, now.add(const Duration(hours: 8)));
    expect(tokens.sessionDeadline, now.add(const Duration(hours: 8)));
  });

  test('rejects responses without authoritative session metadata', () {
    expect(
      () => tokensFromApiPayload({
        'accessToken': 'access',
        'refreshToken': 'refresh',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('persists remembered mobile sessions across process restarts', () async {
    const secureStorage = FlutterSecureStorage();
    final firstProcess = SecureAuthTokenStore(
      storage: secureStorage,
      browserSessionStorage: _FakeBrowserSessionStorage(),
      isWeb: false,
    );
    final remembered = tokensFromApiPayload(_payload(now, remembered: true));

    await firstProcess.save(remembered);
    final restarted = SecureAuthTokenStore(
      storage: secureStorage,
      browserSessionStorage: _FakeBrowserSessionStorage(),
      isWeb: false,
    );

    expect((await restarted.read())?.refreshToken, 'refresh-persistent');
    expect((await restarted.read())?.isRemembered, isTrue);
  });

  test('keeps temporary mobile sessions in memory only', () async {
    const secureStorage = FlutterSecureStorage();
    final firstProcess = SecureAuthTokenStore(
      storage: secureStorage,
      browserSessionStorage: _FakeBrowserSessionStorage(),
      isWeb: false,
    );
    final temporary = tokensFromApiPayload(_payload(now, remembered: false));

    await firstProcess.save(temporary);

    expect((await firstProcess.read())?.refreshToken, 'refresh-temporary');
    final restarted = SecureAuthTokenStore(
      storage: secureStorage,
      browserSessionStorage: _FakeBrowserSessionStorage(),
      isWeb: false,
    );
    expect(await restarted.read(), isNull);
  });

  test('uses browser sessionStorage for temporary web sessions', () async {
    const secureStorage = FlutterSecureStorage();
    final browserSession = _FakeBrowserSessionStorage();
    final firstTab = SecureAuthTokenStore(
      storage: secureStorage,
      browserSessionStorage: browserSession,
      isWeb: true,
    );
    final temporary = tokensFromApiPayload(_payload(now, remembered: false));

    await firstTab.save(temporary);
    final reloadedTab = SecureAuthTokenStore(
      storage: secureStorage,
      browserSessionStorage: browserSession,
      isWeb: true,
    );

    expect((await reloadedTab.read())?.refreshToken, 'refresh-temporary');
    final reopenedTab = SecureAuthTokenStore(
      storage: secureStorage,
      browserSessionStorage: _FakeBrowserSessionStorage(),
      isWeb: true,
    );
    expect(await reopenedTab.read(), isNull);
  });

  test('clear removes memory, secure, browser, and legacy values', () async {
    const secureStorage = FlutterSecureStorage();
    FlutterSecureStorage.setMockInitialValues({
      'yalla_home_refresh_token': 'legacy-refresh',
      'yalla_home_remember_session': 'true',
    });
    final browserSession = _FakeBrowserSessionStorage();
    final store = SecureAuthTokenStore(
      storage: secureStorage,
      browserSessionStorage: browserSession,
      isWeb: true,
    );
    await store.save(tokensFromApiPayload(_payload(now, remembered: false)));

    await store.clear();

    expect(await store.read(), isNull);
    expect(browserSession.values, isEmpty);
    expect(await secureStorage.read(key: 'yalla_home_refresh_token'), isNull);
  });

  test('migrates a legacy remembered refresh safely as temporary', () async {
    const secureStorage = FlutterSecureStorage();
    final startedSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final refresh = _jwt({
      'iat': startedSeconds,
      'exp': startedSeconds + const Duration(days: 30).inSeconds,
    });
    FlutterSecureStorage.setMockInitialValues({
      'yalla_home_refresh_token': refresh,
      'yalla_home_remember_session': 'true',
      'yalla_home_session_expires_at': now
          .add(const Duration(days: 7))
          .toIso8601String(),
    });
    final store = SecureAuthTokenStore(
      storage: secureStorage,
      browserSessionStorage: _FakeBrowserSessionStorage(),
      isWeb: false,
    );

    final migrated = await store.read();

    expect(migrated?.mode, AuthSessionMode.temporary);
    expect(migrated?.hasAccessToken, isFalse);
    expect(migrated?.sessionStartedAt, now);
    expect(migrated?.sessionDeadline, now.add(const Duration(hours: 8)));
    expect(await secureStorage.read(key: 'yalla_home_refresh_token'), isNull);
  });
}

Map<String, dynamic> _payload(DateTime startedAt, {required bool remembered}) {
  final mode = remembered ? 'persistent' : 'temporary';
  final deadline = startedAt.add(
    remembered ? const Duration(days: 7) : const Duration(hours: 8),
  );
  return {
    'accessToken': 'access-$mode',
    'refreshToken': 'refresh-$mode',
    'session': {
      'mode': mode,
      'remember': remembered,
      'startedAt': startedAt.toIso8601String(),
      'absoluteExpiresAt': remembered ? null : deadline.toIso8601String(),
      'accessExpiresAt': startedAt
          .add(const Duration(minutes: 15))
          .toIso8601String(),
      'refreshExpiresAt': deadline.toIso8601String(),
    },
  };
}

final class _FakeBrowserSessionStorage implements BrowserSessionStorage {
  final Map<String, String> values = {};

  @override
  void delete(String key) => values.remove(key);

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;
}

String _jwt(Map<String, Object?> payload) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode(payload)}.signature';
}
