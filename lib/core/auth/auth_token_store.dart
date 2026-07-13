import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'browser_session_storage.dart';
import 'session_metadata.dart';

class StoredAuthTokens {
  const StoredAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    required this.sessionStartedAt,
    required this.mode,
    this.absoluteExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;
  final DateTime sessionStartedAt;
  final AuthSessionMode mode;
  final DateTime? absoluteExpiresAt;

  bool get isRemembered => mode.isRemembered;
  bool get hasAccessToken => accessToken.trim().isNotEmpty;

  DateTime get sessionDeadline => mode == AuthSessionMode.temporary
      ? absoluteExpiresAt ?? refreshExpiresAt
      : refreshExpiresAt;

  bool accessExpiresSoon(
    DateTime now, {
    Duration margin = const Duration(minutes: 1),
  }) {
    return !accessExpiresAt.isAfter(now.add(margin));
  }

  bool sessionHasExpired(DateTime now) => !sessionDeadline.isAfter(now);

  Map<String, Object?> toJson() {
    return {
      'version': 2,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessExpiresAt': accessExpiresAt.toUtc().toIso8601String(),
      'refreshExpiresAt': refreshExpiresAt.toUtc().toIso8601String(),
      'sessionStartedAt': sessionStartedAt.toUtc().toIso8601String(),
      'sessionMode': mode.wireName,
      'absoluteExpiresAt': absoluteExpiresAt?.toUtc().toIso8601String(),
    };
  }

  factory StoredAuthTokens.fromJson(Map<String, dynamic> json) {
    return _validatedTokens(
      StoredAuthTokens(
        accessToken: _requiredString(json, 'accessToken'),
        refreshToken: _requiredString(json, 'refreshToken'),
        accessExpiresAt: _requiredDate(json, 'accessExpiresAt'),
        refreshExpiresAt: _requiredDate(json, 'refreshExpiresAt'),
        sessionStartedAt: _requiredDate(json, 'sessionStartedAt'),
        mode: AuthSessionMode.parse(json['sessionMode']),
        absoluteExpiresAt: _optionalDate(json['absoluteExpiresAt']),
      ),
    );
  }
}

StoredAuthTokens tokensFromApiPayload(Map<String, dynamic> json) {
  final rawSession = json['session'];
  if (rawSession is! Map) {
    throw const FormatException('Missing authentication session metadata.');
  }
  final session = Map<String, dynamic>.from(rawSession);
  final mode = AuthSessionMode.parse(session['mode']);
  final remember = session['remember'];
  if (remember is! bool || remember != mode.isRemembered) {
    throw const FormatException('Invalid authentication session metadata.');
  }

  final absoluteExpiresAt = _optionalDate(session['absoluteExpiresAt']);
  if (mode == AuthSessionMode.temporary && absoluteExpiresAt == null) {
    throw const FormatException('Missing temporary session deadline.');
  }
  if (mode == AuthSessionMode.persistent && absoluteExpiresAt != null) {
    throw const FormatException('Persistent session has an absolute deadline.');
  }

  return _validatedTokens(
    StoredAuthTokens(
      accessToken: _requiredString(json, 'accessToken'),
      refreshToken: _requiredString(json, 'refreshToken'),
      accessExpiresAt: _requiredDate(session, 'accessExpiresAt'),
      refreshExpiresAt: _requiredDate(session, 'refreshExpiresAt'),
      sessionStartedAt: _requiredDate(session, 'startedAt'),
      mode: mode,
      absoluteExpiresAt: absoluteExpiresAt,
    ),
  );
}

abstract interface class AuthTokenStore {
  Future<StoredAuthTokens?> read();

  Future<void> save(StoredAuthTokens tokens);

  Future<void> clear();
}

class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore({
    FlutterSecureStorage? storage,
    BrowserSessionStorage? browserSessionStorage,
    bool? isWeb,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _browserSessionStorage =
           browserSessionStorage ?? createBrowserSessionStorage(),
       _isWeb = isWeb ?? kIsWeb;

  static const _tokensKey = 'yalla_home_auth_tokens_v2';
  static const _browserSessionKey = 'yalla_home_session_tokens_v2';
  static const _legacyRefreshKey = 'yalla_home_refresh_token';
  static const _legacyRememberKey = 'yalla_home_remember_session';
  static const _legacyExpiresAtKey = 'yalla_home_session_expires_at';
  static const _legacyTemporaryMarkerKey =
      'yalla_home_temporary_session_existed';

  final FlutterSecureStorage _storage;
  final BrowserSessionStorage _browserSessionStorage;
  final bool _isWeb;
  StoredAuthTokens? _sessionTokens;

  @override
  Future<StoredAuthTokens?> read() async {
    if (_sessionTokens case final tokens?) return tokens;

    if (_isWeb) {
      final rawBrowserTokens = _browserSessionStorage.read(_browserSessionKey);
      final browserTokens = _decodeTokens(rawBrowserTokens);
      if (browserTokens != null) {
        _sessionTokens = browserTokens;
        return browserTokens;
      }
      if (rawBrowserTokens != null) {
        _browserSessionStorage.delete(_browserSessionKey);
      }
    }

    final rawTokens = await _storage.read(key: _tokensKey);
    final tokens = _decodeTokens(rawTokens);
    if (tokens != null) {
      if (!tokens.isRemembered) {
        await _storage.delete(key: _tokensKey);
        if (_isWeb) {
          _browserSessionStorage.write(
            _browserSessionKey,
            jsonEncode(tokens.toJson()),
          );
        }
        _sessionTokens = tokens;
      }
      return tokens;
    }
    if (rawTokens != null) await _storage.delete(key: _tokensKey);

    final legacy = await _readLegacyRememberedSession();
    await _clearLegacyStorage();
    if (legacy != null) {
      _sessionTokens = legacy;
    }
    return legacy;
  }

  @override
  Future<void> save(StoredAuthTokens tokens) async {
    final encoded = jsonEncode(tokens.toJson());
    await _clearLegacyStorage();
    if (!tokens.isRemembered) {
      await _storage.delete(key: _tokensKey);
      if (_isWeb) {
        _browserSessionStorage.write(_browserSessionKey, encoded);
      }
      _sessionTokens = tokens;
      return;
    }

    _browserSessionStorage.delete(_browserSessionKey);
    await _storage.write(key: _tokensKey, value: encoded);
    _sessionTokens = null;
  }

  @override
  Future<void> clear() async {
    _sessionTokens = null;
    _browserSessionStorage.delete(_browserSessionKey);
    await _storage.delete(key: _tokensKey);
    await _clearLegacyStorage();
  }

  StoredAuthTokens? _decodeTokens(String? rawTokens) {
    if (rawTokens == null || rawTokens.trim().isEmpty) return null;
    try {
      return StoredAuthTokens.fromJson(
        jsonDecode(rawTokens) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<StoredAuthTokens?> _readLegacyRememberedSession() async {
    final remembered = await _storage.read(key: _legacyRememberKey) == 'true';
    final refresh = await _storage.read(key: _legacyRefreshKey);
    if (!remembered || refresh == null || refresh.trim().isEmpty) return null;

    try {
      final payload = _jwtPayload(refresh.trim());
      final startedAt = _epochDate(
        payload['client_session_started_at'] ?? payload['iat'],
      );
      final mode = payload['client_session_mode'] == 'persistent'
          ? AuthSessionMode.persistent
          : AuthSessionMode.temporary;
      final rawRefreshExpiry = _epochDate(payload['exp']);
      final absoluteDeadline = mode == AuthSessionMode.temporary
          ? _epochDateOrNull(payload['client_session_exp']) ??
                startedAt.add(const Duration(hours: 8))
          : null;
      final refreshExpiresAt =
          mode == AuthSessionMode.temporary &&
              absoluteDeadline!.isBefore(rawRefreshExpiry)
          ? absoluteDeadline
          : rawRefreshExpiry;

      return _validatedTokens(
        StoredAuthTokens(
          accessToken: '',
          refreshToken: refresh.trim(),
          accessExpiresAt: startedAt,
          refreshExpiresAt: refreshExpiresAt,
          sessionStartedAt: startedAt,
          mode: mode,
          absoluteExpiresAt: absoluteDeadline,
        ),
        allowMissingAccess: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearLegacyStorage() async {
    await _storage.delete(key: _legacyRefreshKey);
    await _storage.delete(key: _legacyRememberKey);
    await _storage.delete(key: _legacyExpiresAtKey);
    await _storage.delete(key: _legacyTemporaryMarkerKey);
  }
}

class InMemoryAuthTokenStore implements AuthTokenStore {
  StoredAuthTokens? tokens;
  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<StoredAuthTokens?> read() async => tokens;

  @override
  Future<void> save(StoredAuthTokens value) async {
    saveCount += 1;
    tokens = value;
  }

  @override
  Future<void> clear() async {
    clearCount += 1;
    tokens = null;
  }
}

StoredAuthTokens _validatedTokens(
  StoredAuthTokens tokens, {
  bool allowMissingAccess = false,
}) {
  if ((!allowMissingAccess && !tokens.hasAccessToken) ||
      tokens.refreshToken.trim().isEmpty) {
    throw const FormatException('Missing authentication token.');
  }
  if (tokens.mode == AuthSessionMode.temporary &&
      tokens.absoluteExpiresAt == null) {
    throw const FormatException('Missing temporary session deadline.');
  }
  if (tokens.mode == AuthSessionMode.persistent &&
      tokens.absoluteExpiresAt != null) {
    throw const FormatException('Persistent session has an absolute deadline.');
  }
  if (tokens.accessExpiresAt.isAfter(tokens.sessionDeadline) ||
      tokens.refreshExpiresAt.isAfter(tokens.sessionDeadline) ||
      tokens.sessionStartedAt.isAfter(tokens.sessionDeadline)) {
    throw const FormatException('Invalid authentication session timestamps.');
  }
  return tokens;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Missing $key.');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _optionalDate(json[key]);
  if (value != null) return value;
  throw FormatException('Missing $key.');
}

DateTime? _optionalDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}

Map<String, dynamic> _jwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) throw const FormatException('Invalid JWT.');
  final bytes = base64Url.decode(base64Url.normalize(parts[1]));
  return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}

DateTime _epochDate(Object? value) {
  final date = _epochDateOrNull(value);
  if (date != null) return date;
  throw const FormatException('Invalid JWT timestamp.');
}

DateTime? _epochDateOrNull(Object? value) {
  final seconds = switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };
  if (seconds == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    seconds * Duration.millisecondsPerSecond,
    isUtc: true,
  );
}
