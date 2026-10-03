import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tamdansers/services/api_config.dart';
import 'package:tamdansers/services/api_service.dart';

// Answers every request from a handler instead of the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Map<String, Object?> _authResponse(String access, String refresh) => {
      'userId': '00000000-0000-0000-0000-000000000001',
      'firstName': 'Test',
      'lastName': 'User',
      'email': 'test@school.local',
      'role': 2,
      'userRole': 'Student',
      'isActive': true,
      'isEmailVerified': true,
      'token': access,
      'refreshToken': refresh,
    };

// BUGS B26: a 401 from /api/auth/refresh was itself "refreshed" again and again,
// and parallel 401s each spent the same (rotating) refresh token.
void main() {
  late int refreshCalls;

  Future<ApiService> signedInService(_FakeAdapter adapter) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'old-access',
      'refresh_token': 'refresh-1',
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter;
    final api = ApiService.withClient(dio, const FlutterSecureStorage());
    await api.loadTokens();
    return api;
  }

  setUp(() => refreshCalls = 0);

  test('an expired refresh token is tried once and then the session is cleared', () async {
    final api = await signedInService(_FakeAdapter((options) async {
      if (options.path == ApiConfig.refreshTokenEndpoint) {
        // Like the server's rate limiter: ends a runaway refresh loop.
        if (++refreshCalls > 50) return _json({'code': 'TOO_MANY_REQUESTS'}, 429);
      }
      return _json({'message': 'unauthorized'}, 401);
    }));

    final notifications = await api.getNotifications().timeout(const Duration(seconds: 5));

    expect(notifications, isEmpty);
    expect(refreshCalls, 1);
    expect(api.isAuthenticated(), isFalse);
  });

  test('parallel 401s share one refresh and every request is retried', () async {
    final api = await signedInService(_FakeAdapter((options) async {
      if (options.path == ApiConfig.refreshTokenEndpoint) {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _json(_authResponse('new-access', 'refresh-2'), 200);
      }
      if (options.headers['Authorization'] != 'Bearer new-access') {
        return _json({'message': 'expired'}, 401);
      }
      return _json(<Object>[], 200);
    }));

    final results = await Future.wait([
      api.getNotifications(),
      api.getNotifications(unreadOnly: true),
      api.getNotifications(),
    ]).timeout(const Duration(seconds: 5));

    expect(results, hasLength(3));
    expect(refreshCalls, 1);
    expect(api.isAuthenticated(), isTrue);
  });

  test('a request that is still 401 after a refresh is not refreshed again', () async {
    final api = await signedInService(_FakeAdapter((options) async {
      if (options.path == ApiConfig.refreshTokenEndpoint) {
        refreshCalls++;
        return _json(_authResponse('new-access', 'refresh-2'), 200);
      }
      return _json({'message': 'still unauthorized'}, 401);
    }));

    await api.getNotifications().timeout(const Duration(seconds: 5));

    expect(refreshCalls, 1);
  });
}
