import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../network/api_exception.dart';

class AuthSession {
  AuthSession._();

  static final instance = AuthSession._();
  static const _refreshKey = 'yalla_home_refresh_token';
  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String get apiBaseUrl => _configuredApiBaseUrl.isNotEmpty
      ? _configuredApiBaseUrl
      : kIsWeb
          ? 'http://127.0.0.1:8000/api/v1'
          : 'http://10.0.2.2:8000/api/v1';

  final _client = http.Client();
  final _storage = const FlutterSecureStorage();
  String? _accessToken;
  String? _refreshToken;
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

  Future<bool> restore() async {
    final savedRefresh = await _storage.read(key: _refreshKey);
    if (savedRefresh == null || savedRefresh.isEmpty) return false;
    _refreshToken = savedRefresh;
    try {
      await _refresh();
      currentUser = await getJson('auth/me/') as Map<String, dynamic>;
      if (currentUser?['role'] == 'representative') return true;
      await clear();
      return false;
    } catch (_) {
      await clear();
      return false;
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
    required bool remember,
  }) async {
    final response = await _client.post(
      uri('auth/login/representative/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _message(data, 'تعذر تسجيل الدخول.'),
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
      throw const ApiException('استجابة تسجيل الدخول غير مكتملة.');
    }
    if (remember) {
      await _storage.write(key: _refreshKey, value: _refreshToken);
    } else {
      await _storage.delete(key: _refreshKey);
    }
  }

  Future<dynamic> getJson(String path) async {
    var response = await _authorizedGet(path);
    if (response.statusCode == 401 && await _tryRefresh()) {
      response = await _authorizedGet(path);
    }
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _message(data, 'تعذر تحميل البيانات.'),
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
        _message(data, 'تعذر تأكيد التسليم.'),
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
    _accessToken = null;
    _refreshToken = null;
    currentUser = null;
    await _storage.delete(key: _refreshKey);
  }

  Future<http.Response> _authorizedGet(String path) {
    return _client.get(
      uri(path),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );
  }

  Future<bool> _tryRefresh() async {
    try {
      await _refresh();
      return true;
    } catch (_) {
      await clear();
      return false;
    }
  }

  Future<void> _refresh() async {
    final refresh = _refreshToken;
    if (refresh == null) throw const ApiException('لا توجد جلسة محفوظة.');
    final response = await _client.post(
      uri('auth/refresh/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refresh}),
    );
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _message(data, 'انتهت الجلسة.'),
        statusCode: response.statusCode,
      );
    }
    final map = data as Map<String, dynamic>;
    _accessToken = map['accessToken']?.toString();
    _refreshToken = map['refreshToken']?.toString() ?? refresh;
    final persisted = await _storage.read(key: _refreshKey);
    if (persisted != null) {
      await _storage.write(key: _refreshKey, value: _refreshToken);
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
    if (data is String && data.trim().isNotEmpty) return data;
    if (data is List) {
      for (final value in data) {
        final message = _message(value, '');
        if (message.isNotEmpty) return message;
      }
    }
    if (data is Map) {
      if (data['detail'] is String) return data['detail'] as String;
      for (final value in data.values) {
        final message = _message(value, '');
        if (message.isNotEmpty) return message;
      }
    }
    return fallback;
  }
}
