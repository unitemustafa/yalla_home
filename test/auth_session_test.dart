import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yalla_home/core/auth/auth_session.dart';
import 'package:yalla_home/core/auth/auth_token_store.dart';
import 'package:yalla_home/core/auth/session_metadata.dart';
import 'package:yalla_home/core/network/api_exception.dart';

void main() {
  final base = DateTime.utc(2030, 1, 1, 8);

  test('login sends remember=false and keeps the temporary deadline', () async {
    final store = InMemoryAuthTokenStore();
    late Map<String, dynamic> requestBody;
    final session = AuthSession.forTesting(
      tokenStore: store,
      now: () => base,
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _response(_payload(base, remembered: false));
      }),
    );
    addTearDown(session.disposeForTesting);

    await session.login(
      identifier: 'captain@example.com',
      password: 'Secret123!',
      remember: false,
    );

    expect(requestBody['remember'], isFalse);
    expect(store.tokens?.mode, AuthSessionMode.temporary);
    expect(store.tokens?.absoluteExpiresAt, base.add(const Duration(hours: 8)));
  });

  test(
    'proactively refreshes and atomically stores both rotated tokens',
    () async {
      final store = InMemoryAuthTokenStore();
      var refreshRequests = 0;
      final session = AuthSession.forTesting(
        tokenStore: store,
        now: () => base,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login/representative/')) {
            expect(
              (jsonDecode(request.body) as Map<String, dynamic>)['remember'],
              isTrue,
            );
            return _response(
              _payload(
                base,
                remembered: true,
                accessExpiresAt: base.add(const Duration(seconds: 30)),
              ),
            );
          }
          if (request.url.path.endsWith('/refresh/')) {
            refreshRequests += 1;
            expect(jsonDecode(request.body), {'refreshToken': 'refresh-old'});
            return _response(
              _payload(
                base,
                remembered: true,
                accessToken: 'access-rotated',
                refreshToken: 'refresh-rotated',
              ),
            );
          }
          expect(request.headers['authorization'], 'Bearer access-rotated');
          return _response({'ok': true});
        }),
      );
      addTearDown(session.disposeForTesting);

      await session.login(
        identifier: 'captain@example.com',
        password: 'Secret123!',
        remember: true,
      );
      final result = await session.getJson('courier/orders/');

      expect(result['ok'], isTrue);
      expect(refreshRequests, 1);
      expect(store.tokens?.accessToken, 'access-rotated');
      expect(store.tokens?.refreshToken, 'refresh-rotated');
      expect(store.saveCount, 2);
    },
  );

  test('concurrent requests share one refresh operation', () async {
    final store = InMemoryAuthTokenStore();
    final refreshStarted = Completer<void>();
    final releaseRefresh = Completer<void>();
    var refreshRequests = 0;
    var protectedRequests = 0;
    final session = AuthSession.forTesting(
      tokenStore: store,
      now: () => base,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login/representative/')) {
          return _response(
            _payload(
              base,
              remembered: false,
              accessExpiresAt: base.add(const Duration(seconds: 30)),
            ),
          );
        }
        if (request.url.path.endsWith('/refresh/')) {
          refreshRequests += 1;
          if (!refreshStarted.isCompleted) refreshStarted.complete();
          await releaseRefresh.future;
          return _response(
            _payload(
              base,
              remembered: false,
              accessToken: 'access-rotated',
              refreshToken: 'refresh-rotated',
            ),
          );
        }
        protectedRequests += 1;
        expect(request.headers['authorization'], 'Bearer access-rotated');
        return _response({'request': protectedRequests});
      }),
    );
    addTearDown(session.disposeForTesting);
    await session.login(
      identifier: 'captain@example.com',
      password: 'Secret123!',
      remember: false,
    );

    final requests = [
      session.getJson('courier/orders/'),
      session.getJson('auth/me/'),
      session.getJson('notifications/unread-count/'),
    ];
    await refreshStarted.future;
    expect(refreshRequests, 1);
    releaseRefresh.complete();
    await Future.wait(requests);

    expect(refreshRequests, 1);
    expect(protectedRequests, 3);
    expect(store.saveCount, 2);
  });

  test('an in-flight refresh cannot revive a cleared session', () async {
    final store = InMemoryAuthTokenStore();
    final refreshStarted = Completer<void>();
    final releaseRefresh = Completer<void>();
    final session = AuthSession.forTesting(
      tokenStore: store,
      now: () => base,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login/representative/')) {
          return _response(
            _payload(
              base,
              remembered: true,
              accessExpiresAt: base.add(const Duration(seconds: 30)),
            ),
          );
        }
        if (request.url.path.endsWith('/refresh/')) {
          refreshStarted.complete();
          await releaseRefresh.future;
          return _response(
            _payload(
              base,
              remembered: true,
              accessToken: 'stale-access',
              refreshToken: 'stale-refresh',
            ),
          );
        }
        return _response({'unexpected': true});
      }),
    );
    addTearDown(session.disposeForTesting);
    await session.login(
      identifier: 'captain@example.com',
      password: 'Secret123!',
      remember: true,
    );

    final request = session.getJson('courier/orders/');
    await refreshStarted.future;
    await session.clear();
    releaseRefresh.complete();

    await expectLater(request, throwsA(isA<ApiException>()));
    expect(store.tokens, isNull);
    expect(session.tokensForTesting, isNull);
  });

  test('reactive 401 refreshes and retries only once', () async {
    final store = InMemoryAuthTokenStore();
    var refreshRequests = 0;
    var protectedRequests = 0;
    final session = AuthSession.forTesting(
      tokenStore: store,
      now: () => base,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login/representative/')) {
          return _response(_payload(base, remembered: false));
        }
        if (request.url.path.endsWith('/refresh/')) {
          refreshRequests += 1;
          return _response(
            _payload(
              base,
              remembered: false,
              accessToken: 'access-rotated',
              refreshToken: 'refresh-rotated',
            ),
          );
        }
        protectedRequests += 1;
        if (request.headers['authorization'] == 'Bearer access-old') {
          return _response({'code': 'token_not_valid'}, statusCode: 401);
        }
        return _response({'ok': true});
      }),
    );
    addTearDown(session.disposeForTesting);
    await session.login(
      identifier: 'captain@example.com',
      password: 'Secret123!',
      remember: false,
    );

    final result = await session.getJson('courier/orders/');

    expect(result['ok'], isTrue);
    expect(refreshRequests, 1);
    expect(protectedRequests, 2);
  });

  test('refresh failure clears the session cleanly', () async {
    final store = InMemoryAuthTokenStore();
    final session = AuthSession.forTesting(
      tokenStore: store,
      now: () => base,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login/representative/')) {
          return _response(_payload(base, remembered: false));
        }
        if (request.url.path.endsWith('/refresh/')) {
          return _response({'code': 'token_not_valid'}, statusCode: 401);
        }
        return _response({'code': 'token_not_valid'}, statusCode: 401);
      }),
    );
    addTearDown(session.disposeForTesting);
    await session.login(
      identifier: 'captain@example.com',
      password: 'Secret123!',
      remember: false,
    );

    await expectLater(
      session.getJson('courier/orders/'),
      throwsA(isA<ApiException>()),
    );

    expect(store.tokens, isNull);
    expect(session.currentUser, isNull);
  });

  test('temporary session is cleared at the exact eight-hour deadline', () {
    fakeAsync((async) {
      final store = InMemoryAuthTokenStore();
      final session = AuthSession.forTesting(
        tokenStore: store,
        now: () => base.add(async.elapsed),
        client: MockClient(
          (_) async => _response(_payload(base, remembered: false)),
        ),
      );
      session.login(
        identifier: 'captain@example.com',
        password: 'Secret123!',
        remember: false,
      );
      async.flushMicrotasks();

      async.elapse(const Duration(hours: 7, minutes: 59));
      async.flushMicrotasks();
      expect(store.tokens, isNotNull);

      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();
      expect(store.tokens, isNull);
      expect(session.currentUser, isNull);

      session.disposeForTesting();
    });
  });

  test('successful foreground refresh rearms the seven-day window', () {
    fakeAsync((async) {
      final store = InMemoryAuthTokenStore();
      var refreshRequests = 0;
      final session = AuthSession.forTesting(
        tokenStore: store,
        now: () => base.add(async.elapsed),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login/representative/')) {
            return _response(_payload(base, remembered: true));
          }
          if (request.url.path.endsWith('/refresh/')) {
            refreshRequests += 1;
            final refreshedAt = base.add(async.elapsed);
            return _response(
              _payload(
                base,
                remembered: true,
                accessToken: 'access-rotated',
                refreshToken: 'refresh-rotated',
                accessExpiresAt: refreshedAt.add(const Duration(minutes: 15)),
                refreshExpiresAt: refreshedAt.add(const Duration(days: 7)),
              ),
            );
          }
          return _response({'ok': true});
        }),
      );
      session.login(
        identifier: 'captain@example.com',
        password: 'Secret123!',
        remember: true,
      );
      async.flushMicrotasks();

      async.elapse(const Duration(days: 6));
      session.validateForForeground();
      async.flushMicrotasks();
      expect(refreshRequests, 1);

      async.elapse(const Duration(days: 1));
      async.flushMicrotasks();
      expect(store.tokens, isNotNull);

      async.elapse(const Duration(days: 6));
      async.flushMicrotasks();
      expect(store.tokens, isNull);

      session.disposeForTesting();
    });
  });

  test(
    'startup restores, refreshes, and validates a remembered courier',
    () async {
      final store = InMemoryAuthTokenStore();
      await store.save(tokensFromApiPayload(_payload(base, remembered: true)));
      final now = base.add(const Duration(days: 1));
      var refreshRequests = 0;
      var meRequests = 0;
      final session = AuthSession.forTesting(
        tokenStore: store,
        now: () => now,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/refresh/')) {
            refreshRequests += 1;
            return _response(
              _payload(
                base,
                remembered: true,
                accessToken: 'access-restored',
                refreshToken: 'refresh-restored',
                accessExpiresAt: now.add(const Duration(minutes: 15)),
                refreshExpiresAt: now.add(const Duration(days: 7)),
              ),
            );
          }
          meRequests += 1;
          expect(request.headers['authorization'], 'Bearer access-restored');
          return _response({
            'id': '7',
            'role': 'representative',
            'email': 'captain@example.com',
          });
        }),
      );
      addTearDown(session.disposeForTesting);

      final result = await session.restore();

      expect(result, AuthRestoreResult.restored);
      expect(refreshRequests, 1);
      expect(meRequests, 1);
      expect(session.currentUser?['role'], 'representative');
      expect(store.tokens?.refreshToken, 'refresh-restored');
    },
  );

  test('account_inactive clears a live courier session', () async {
    final store = InMemoryAuthTokenStore();
    final session = AuthSession.forTesting(
      tokenStore: store,
      now: () => base,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login/representative/')) {
          return _response(_payload(base, remembered: true));
        }
        return _response({
          'code': 'account_inactive',
          'detail': 'Account inactive.',
        }, statusCode: 403);
      }),
    );
    addTearDown(session.disposeForTesting);
    await session.login(
      identifier: 'captain@example.com',
      password: 'Secret123!',
      remember: true,
    );

    await expectLater(
      session.getJson('auth/me/'),
      throwsA(isA<ApiException>()),
    );

    expect(store.tokens, isNull);
    expect(session.currentUser, isNull);
  });

  test(
    'logout refreshes if needed and revokes the latest rotated token',
    () async {
      final store = InMemoryAuthTokenStore();
      var logoutRefreshToken = '';
      final session = AuthSession.forTesting(
        tokenStore: store,
        now: () => base,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login/representative/')) {
            return _response(
              _payload(
                base,
                remembered: true,
                accessExpiresAt: base.add(const Duration(seconds: 30)),
              ),
            );
          }
          if (request.url.path.endsWith('/refresh/')) {
            return _response(
              _payload(
                base,
                remembered: true,
                accessToken: 'access-rotated',
                refreshToken: 'refresh-rotated',
              ),
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          logoutRefreshToken = body['refreshToken'] as String;
          expect(request.headers['authorization'], 'Bearer access-rotated');
          return _response({'detail': 'Logout successful.'});
        }),
      );
      addTearDown(session.disposeForTesting);
      await session.login(
        identifier: 'captain@example.com',
        password: 'Secret123!',
        remember: true,
      );

      await session.logout();

      expect(logoutRefreshToken, 'refresh-rotated');
      expect(store.tokens, isNull);
    },
  );
}

Map<String, dynamic> _payload(
  DateTime startedAt, {
  required bool remembered,
  String accessToken = 'access-old',
  String refreshToken = 'refresh-old',
  DateTime? accessExpiresAt,
  DateTime? refreshExpiresAt,
}) {
  final mode = remembered ? 'persistent' : 'temporary';
  final deadline =
      refreshExpiresAt ??
      startedAt.add(
        remembered ? const Duration(days: 7) : const Duration(hours: 8),
      );
  return {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'session': {
      'mode': mode,
      'remember': remembered,
      'startedAt': startedAt.toIso8601String(),
      'absoluteExpiresAt': remembered ? null : deadline.toIso8601String(),
      'accessExpiresAt':
          (accessExpiresAt ?? startedAt.add(const Duration(minutes: 15)))
              .toIso8601String(),
      'refreshExpiresAt': deadline.toIso8601String(),
    },
    'user': {
      'id': '7',
      'role': 'representative',
      'email': 'captain@example.com',
    },
  };
}

http.Response _response(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}
