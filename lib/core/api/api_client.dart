import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exception.dart';
import 'token_store.dart';

/// 서버 주소
///
/// 기기마다 "localhost"가 가리키는 곳이 달라서 기본값을 나눠 둔다.
/// 실기기는 맥의 LAN IP를 알아야 하므로 빌드할 때 넣는다:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8001
/// ```
String get apiBaseUrl {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;

  // 안드로이드 에뮬레이터에서 호스트(맥)는 10.0.2.2 다. localhost는 에뮬레이터 자신.
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8001';
  return 'http://localhost:8001';
}

/// 서버와 이야기하는 창구 하나
///
/// - 요청마다 access 토큰을 붙인다
/// - 401이 오면 refresh 로 한 번 되살리고 원래 요청을 다시 보낸다
/// - 서버 에러 봉투(`{detail:{code,message}}`)를 [ApiException]으로 바꾼다
class ApiClient {
  ApiClient._() {
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  static final ApiClient instance = ApiClient._();

  /// 토큰 없이 부르는 엔드포인트
  ///
  /// `/auth/` 전체를 빼면 안 된다 — `/auth/me`·`/auth/logout` 은 토큰이
  /// 있어야 하고, 안 붙이면 자동 로그인이 영영 안 된다.
  static const _publicPaths = {
    '/auth/login',
    '/auth/signup',
    '/auth/refresh',
    '/auth/password-reset/request',
    '/auth/password-reset/verify',
    '/auth/password-reset/confirm',
  };

  static bool _isPublic(String path) => _publicPaths.contains(path);

  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 20),
      // 상태 코드로 던지지 않고 우리가 직접 판단한다 (에러 봉투를 읽어야 해서)
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  /// 토큰이 만료돼 로그아웃까지 간 경우 알린다 — 최상위 게이트가 로그인 화면으로 되돌린다
  VoidCallback? onSessionExpired;

  /// refresh 를 여러 요청이 동시에 부르지 않도록 하나로 묶는다
  Future<bool>? _refreshing;

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = TokenStore.instance.accessToken;
    if (token != null && !_isPublic(options.path)) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler handler) async {
    // 네트워크가 아예 안 될 때 — 서버 응답이 없으므로 그대로 메시지를 만들어 준다
    if (e.response == null) {
      return handler.reject(e.copyWith(error: ApiException.network(e.type)));
    }
    handler.next(e);
  }

  /// 요청 한 번 — 401이면 토큰을 되살려 한 번만 재시도한다
  Future<Response<dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    Future<Response<dynamic>> once() => dio.request<dynamic>(
      path,
      data: body,
      queryParameters: query,
      options: Options(method: method),
    );

    var response = await once();
    if (response.statusCode == 401 && !_isPublic(path)) {
      if (await _refresh()) {
        response = await once();
      } else {
        onSessionExpired?.call();
      }
    }

    final status = response.statusCode ?? 0;
    if (status >= 400) throw ApiException.fromResponse(response);
    return response;
  }

  /// access 토큰 재발급 — 성공하면 true
  Future<bool> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refreshToken = TokenStore.instance.refreshToken;
    if (refreshToken == null) return false;

    final response = await dio.post<dynamic>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    if (response.statusCode != 200) {
      await TokenStore.instance.clear();
      return false;
    }
    final data = response.data as Map<String, dynamic>;
    await TokenStore.instance.setAccessToken(data['accessToken'] as String);
    return true;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _send('GET', path, query: query);
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _send('GET', path, query: query);
    return response.data as List<dynamic>;
  }

  /// 본문이 없는 응답(204)도 있어서 Map 이 아닐 수 있다
  Future<Map<String, dynamic>?> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final response = await _send('POST', path, body: body, query: query);
    final data = response.data;
    return data is Map ? data.cast<String, dynamic>() : null;
  }

  Future<Map<String, dynamic>?> patch(String path, {Object? body}) async {
    final response = await _send('PATCH', path, body: body);
    final data = response.data;
    return data is Map ? data.cast<String, dynamic>() : null;
  }

  Future<void> delete(String path) => _send('DELETE', path);
}
