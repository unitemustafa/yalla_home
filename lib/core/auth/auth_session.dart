import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../network/api_exception.dart';
import 'session_expired_notifier.dart';

enum AuthRestoreResult { restored, noSession, expired, temporaryFailure }

class AuthSession {
  AuthSession._();

  static final instance = AuthSession._();

  static const _refreshKey = 'yalla_home_refresh_token';
  static const _rememberKey = 'yalla_home_remember_session';
  static const _expiresAtKey = 'yalla_home_session_expires_at';
  static const _temporarySessionMarkerKey =
      'yalla_home_temporary_session_existed';
  static const _rememberedSessionDuration = Duration(days: 7);
  static const _temporarySessionDuration = Duration(hours: 8);
  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    final configured = _configuredApiBaseUrl.trim();
    final baseUrl = configured.isNotEmpty
        ? configured
        : kIsWeb
        ? 'http://127.0.0.1:8000/api/v1'
        : 'http://10.0.2.2:8000/api/v1';
    return _normalizeApiBaseUrl(baseUrl);
  }

  static String _normalizeApiBaseUrl(String baseUrl) {
    final uri = Uri.parse(baseUrl.trim());
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.isEmpty) return uri.replace(path: '/api/v1').toString();
    return uri.replace(path: path).toString();
  }

  final _client = http.Client();
  final _storage = const FlutterSecureStorage();

  String? _accessToken;
  String? _refreshToken;
  Future<void>? _refreshInFlight;
  Timer? _expiryTimer;
  DateTime? _sessionExpiresAt;
  bool _rememberSession = false;
  bool _sessionExpiredEventSent = false;
  int _sessionVersion = 0;

  Map<String, dynamic>? currentUser;

  Uri uri(String path) =>
      Uri.parse('$apiBaseUrl/${path.replaceFirst(RegExp(r'^/+'), '')}');

  String? absoluteUrl(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    if (text.startsWith('http://') || text.startsWith('https://')) return text;
    final root = Uri.parse(apiBaseUrl).origin;
    return '$root/${text.replaceFirst(RegExp(r'^/+'), '')}';
  }

  Future<AuthRestoreResult> restore() async {
    final rememberValue = await _storage.read(key: _rememberKey);
    final savedRefresh = await _storage.read(key: _refreshKey);
    final expiresAtValue = await _storage.read(key: _expiresAtKey);
    final hadTemporarySession = await _storage.read(
      key: _temporarySessionMarkerKey,
    );

    final hasRememberFlag = rememberValue == 'true';
    final hasRefresh = savedRefresh != null && savedRefresh.trim().isNotEmpty;
    final expiresAt = DateTime.tryParse(expiresAtValue ?? '')?.toUtc();
    final hasCompleteRememberedSession =
        hasRememberFlag && hasRefresh && expiresAt != null;

    if (!hasCompleteRememberedSession) {
      if (hasRememberFlag || hasRefresh || (expiresAtValue ?? '').isNotEmpty) {
        await _clearRememberedStorage();
      }
      if (hadTemporarySession != null) {
        await _expireSession(notify: true);
        return AuthRestoreResult.expired;
      }
      return AuthRestoreResult.noSession;
    }

    await _storage.delete(key: _temporarySessionMarkerKey);

    if (!_isBeforeExpiry(expiresAt)) {
      await _expireSession(notify: true);
      return AuthRestoreResult.expired;
    }

    _refreshToken = savedRefresh.trim();
    _sessionExpiresAt = expiresAt;
    _rememberSession = true;
    _sessionExpiredEventSent = false;
    _scheduleExpiryTimer();

    try {
      await _refreshOnce();
      final user = await _fetchCurrentUserForRestore();
      if (user['role'] == 'representative') {
        currentUser = user;
        return AuthRestoreResult.restored;
      }
      await _expireSession(notify: true);
      return AuthRestoreResult.expired;
    } on ApiException catch (error) {
      if (_isAuthenticationFailure(error.statusCode)) {
        await _expireSession(notify: true);
        return AuthRestoreResult.expired;
      }
      return AuthRestoreResult.temporaryFailure;
    } catch (_) {
      return AuthRestoreResult.temporaryFailure;
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
    required bool remember,
  }) async {
    final cleanIdentifier = _removeWhitespace(identifier);
    final cleanPassword = _removeWhitespace(password);
    final response = await _client.post(
      uri('auth/login/representative/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': cleanIdentifier,
        'password': cleanPassword,
      }),
    );
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _message(
          data,
          '\u062a\u0639\u0630\u0631 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644.',
        ),
        statusCode: response.statusCode,
      );
    }

    final map = data as Map<String, dynamic>;
    _accessToken = map['accessToken']?.toString();
    _refreshToken = map['refreshToken']?.toString();
    currentUser = map['user'] as Map<String, dynamic>?;
    if (_accessToken == null ||
        _refreshToken == null ||
        currentUser?['role'] != 'representative') {
      await clear();
      throw const ApiException(
        '\u0627\u0633\u062a\u062c\u0627\u0628\u0629 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u063a\u064a\u0631 \u0645\u0643\u062a\u0645\u0644\u0629.',
      );
    }

    _sessionVersion += 1;
    _rememberSession = remember;
    _sessionExpiredEventSent = false;
    _sessionExpiresAt = DateTime.now().toUtc().add(
      remember ? _rememberedSessionDuration : _temporarySessionDuration,
    );
    _scheduleExpiryTimer();

    if (remember) {
      await _storage.write(key: _refreshKey, value: _refreshToken);
      await _storage.write(key: _rememberKey, value: 'true');
      await _storage.write(
        key: _expiresAtKey,
        value: _sessionExpiresAt!.toIso8601String(),
      );
      await _storage.delete(key: _temporarySessionMarkerKey);
    } else {
      await _storage.delete(key: _refreshKey);
      await _storage.delete(key: _rememberKey);
      await _storage.delete(key: _expiresAtKey);
      await _storage.write(key: _temporarySessionMarkerKey, value: 'true');
    }
  }

  Future<dynamic> getJson(String path) async {
    await _ensureSessionStillActive();
    var response = await _authorizedGet(path);
    if (response.statusCode == 401 && await _tryRefresh()) {
      response = await _authorizedGet(path);
    }
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _message(
          data,
          '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0628\u064a\u0627\u0646\u0627\u062a.',
        ),
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<dynamic> postMultipart(
    String path, {
    String? note,
    List<int>? proofBytes,
    String? proofName,
  }) async {
    await _ensureSessionStillActive();
    Future<http.StreamedResponse> send() async {
      final request = http.MultipartRequest('POST', uri(path));
      request.headers['Authorization'] = 'Bearer $_accessToken';
      if (note != null && note.trim().isNotEmpty) {
        request.fields['note'] = note.trim();
      }
      if (proofBytes != null && proofName != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'proof',
            proofBytes,
            filename: proofName,
          ),
        );
      }
      return request.send();
    }

    var streamed = await send();
    if (streamed.statusCode == 401 && await _tryRefresh()) {
      streamed = await send();
    }
    final response = await http.Response.fromStream(streamed);
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _message(
          data,
          '\u062a\u0639\u0630\u0631 \u062a\u0623\u0643\u064a\u062f \u0627\u0644\u062a\u0633\u0644\u064a\u0645.',
        ),
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<void> logout() async {
    final refresh = _refreshToken;
    if (refresh != null && _accessToken != null) {
      try {
        await _client.post(
          uri('auth/logout/'),
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'refreshToken': refresh}),
        );
      } catch (_) {
        // Local logout must still complete when the network is unavailable.
      }
    }
    await clear();
  }

  Future<void> clear() async {
    _sessionVersion += 1;
    _accessToken = null;
    _refreshToken = null;
    _sessionExpiresAt = null;
    _rememberSession = false;
    _sessionExpiredEventSent = false;
    _refreshInFlight = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    currentUser = null;
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _rememberKey);
    await _storage.delete(key: _expiresAtKey);
    await _storage.delete(key: _temporarySessionMarkerKey);
  }

  Future<Map<String, dynamic>> _fetchCurrentUserForRestore() async {
    final response = await _authorizedGet('auth/me/');
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _message(
          data,
          '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062d\u0633\u0627\u0628.',
        ),
        statusCode: response.statusCode,
      );
    }
    if (data is Map<String, dynamic>) return data;
    throw const ApiException(
      '\u062a\u0639\u0630\u0631 \u0642\u0631\u0627\u0621\u0629 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062d\u0633\u0627\u0628.',
    );
  }

  Future<http.Response> _authorizedGet(String path) {
    return _client.get(
      uri(path),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );
  }

  Future<bool> _tryRefresh() async {
    try {
      await _refreshOnce();
      return _accessToken != null;
    } catch (_) {
      await _expireSession(notify: true);
      return false;
    }
  }

  Future<void> _refreshOnce() async {
    final activeRefresh = _refreshInFlight;

    if (activeRefresh != null) {
      await activeRefresh;
      return;
    }

    final refreshFuture = _refresh();
    _refreshInFlight = refreshFuture;

    try {
      await refreshFuture;
    } finally {
      if (identical(_refreshInFlight, refreshFuture)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<void> _refresh() async {
    if (_isSessionExpired()) {
      throw const ApiException(
        '\u0627\u0646\u062a\u0647\u062a \u0627\u0644\u062c\u0644\u0633\u0629.',
      );
    }

    final refreshVersion = _sessionVersion;
    final refresh = _refreshToken;
    if (refresh == null) {
      throw const ApiException(
        '\u0644\u0627 \u062a\u0648\u062c\u062f \u062c\u0644\u0633\u0629 \u0645\u062d\u0641\u0648\u0638\u0629.',
      );
    }

    final response = await _client.post(
      uri('auth/refresh/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refresh}),
    );
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _message(
          data,
          '\u0627\u0646\u062a\u0647\u062a \u0627\u0644\u062c\u0644\u0633\u0629.',
        ),
        statusCode: response.statusCode,
      );
    }

    if (refreshVersion != _sessionVersion) return;

    final map = data as Map<String, dynamic>;
    _accessToken = map['accessToken']?.toString();
    _refreshToken = map['refreshToken']?.toString() ?? refresh;
    if (_rememberSession) {
      await _storage.write(key: _refreshKey, value: _refreshToken);
    }
  }

  bool _isBeforeExpiry(DateTime expiresAt) {
    return DateTime.now().toUtc().isBefore(expiresAt);
  }

  bool _isSessionExpired() {
    final expiresAt = _sessionExpiresAt;
    return expiresAt == null || !_isBeforeExpiry(expiresAt);
  }

  bool _isAuthenticationFailure(int? statusCode) {
    return statusCode == 400 || statusCode == 401 || statusCode == 403;
  }

  Future<void> _clearRememberedStorage() async {
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _rememberKey);
    await _storage.delete(key: _expiresAtKey);
  }

  Future<void> _ensureSessionStillActive() async {
    if (!_isSessionExpired()) return;
    await _expireSession(notify: true);
    throw const ApiException(
      '\u0627\u0646\u062a\u0647\u062a \u0627\u0644\u062c\u0644\u0633\u0629.',
    );
  }

  void _scheduleExpiryTimer() {
    _expiryTimer?.cancel();
    final expiresAt = _sessionExpiresAt;
    if (expiresAt == null) return;
    final delay = expiresAt.difference(DateTime.now().toUtc());
    _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      unawaited(_expireSession(notify: true));
    });
  }

  Future<void> _expireSession({required bool notify}) async {
    final shouldNotify = notify && !_sessionExpiredEventSent;
    _sessionVersion += 1;
    _accessToken = null;
    _refreshToken = null;
    _sessionExpiresAt = null;
    _rememberSession = false;
    _refreshInFlight = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    currentUser = null;
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _rememberKey);
    await _storage.delete(key: _expiresAtKey);
    await _storage.delete(key: _temporarySessionMarkerKey);
    if (shouldNotify) {
      _sessionExpiredEventSent = true;
      SessionExpiredNotifier.instance.notifyExpired();
    }
  }

  dynamic _decode(http.Response response) {
    if (response.body.trim().isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  String _message(dynamic data, String fallback) {
    if (data is String && data.trim().isNotEmpty) {
      return _localizedMessage(data);
    }
    if (data is List) {
      for (final value in data) {
        final message = _message(value, '');
        if (message.isNotEmpty) return message;
      }
    }
    if (data is Map) {
      if (data['code'] is String) {
        return _localizedCode(data['code'] as String);
      }
      if (data['detail'] is String) {
        return _localizedMessage(data['detail'] as String);
      }
      for (final value in data.values) {
        final message = _message(value, '');
        if (message.isNotEmpty) return message;
      }
    }
    return _localizedMessage(fallback);
  }

  String _localizedMessage(String message) {
    final normalized = message.trim().toLowerCase();
    if (normalized.contains('invalid email or password')) {
      return _invalidCredentialsMessage;
    }
    if (normalized.contains('this account belongs to an admin')) {
      return _localizedCode('admin_account_not_allowed');
    }
    if (normalized.contains('this account belongs to a client')) {
      return _localizedCode('client_account_not_allowed');
    }
    if (normalized.contains('this login is only for representative accounts')) {
      return _localizedCode('representative_account_required');
    }
    if (normalized.contains('account email has not been verified')) {
      return '\u0627\u0644\u062d\u0633\u0627\u0628 \u0644\u0645 \u064a\u062a\u0645 \u062a\u0641\u0639\u064a\u0644\u0647 \u0628\u0639\u062f.';
    }
    if (normalized.contains('not found')) {
      return '\u0627\u0644\u0645\u0633\u0627\u0631 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f. \u062a\u0623\u0643\u062f \u0645\u0646 \u0625\u0639\u062f\u0627\u062f \u0631\u0627\u0628\u0637 \u0627\u0644\u062e\u0627\u062f\u0645.';
    }
    return message;
  }

  String _localizedCode(String code) {
    return switch (code.trim()) {
      'admin_account_not_allowed' =>
        '\u0647\u0630\u0627 \u062d\u0633\u0627\u0628 \u0645\u0633\u0624\u0648\u0644\u060c \u0633\u062c\u0651\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0645\u0646 \u0644\u0648\u062d\u0629 \u0627\u0644\u0625\u062f\u0627\u0631\u0629.',
      'client_account_not_allowed' =>
        '\u0647\u0630\u0627 \u062d\u0633\u0627\u0628 \u0639\u0645\u064a\u0644\u060c \u0627\u0633\u062a\u062e\u062f\u0645 \u062a\u0637\u0628\u064a\u0642 \u064a\u0644\u0627 \u0645\u0627\u0631\u0643\u062a.',
      'representative_account_required' =>
        '\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0647\u0646\u0627 \u0645\u062e\u0635\u0635 \u0644\u062d\u0633\u0627\u0628\u0627\u062a \u0627\u0644\u0645\u0646\u062f\u0648\u0628\u064a\u0646 \u0641\u0642\u0637.',
      _ => code,
    };
  }

  String _removeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), '');
  }

  static const _invalidCredentialsMessage =
      '\u0627\u0644\u0625\u064a\u0645\u064a\u0644 \u0623\u0648 \u0643\u0644\u0645\u0629 \u0627\u0644\u0633\u0631 \u063a\u064a\u0631 \u0635\u062d\u064a\u062d\u064a\u0646.';
}
