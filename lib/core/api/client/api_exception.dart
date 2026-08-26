import 'package:dio/dio.dart';

/// 서버가 돌려준 에러
///
/// 서버는 항상 `{ "detail": { "code": ..., "message": ... } }` 꼴로 준다.
/// 화면에는 [message]를 그대로 보여주면 되고, 분기가 필요할 때만 [code]를 본다.
class ApiException implements Exception {
  ApiException({required this.code, required this.message, this.status});

  final String code;
  final String message;
  final int? status;

  /// 서버까지 못 간 경우 — 주소가 틀렸거나 서버가 꺼져 있거나 와이파이가 없다
  factory ApiException.network(DioExceptionType type) {
    final message = switch (type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => '서버 응답이 너무 느려요. 잠시 후 다시 시도해 주세요.',
      _ => '서버에 연결할 수 없어요. 네트워크를 확인해 주세요.',
    };
    return ApiException(code: 'NETWORK', message: message);
  }

  factory ApiException.fromResponse(Response<dynamic> response) {
    final status = response.statusCode;
    final data = response.data;

    if (data is Map) {
      final detail = data['detail'];
      // 우리 서버의 에러 봉투
      if (detail is Map) {
        return ApiException(
          code: (detail['code'] ?? 'UNKNOWN').toString(),
          message: (detail['message'] ?? '요청을 처리하지 못했어요.').toString(),
          status: status,
        );
      }
      // FastAPI 기본 검증 오류는 detail 이 문자열이거나 리스트로 온다
      if (detail is String) {
        return ApiException(
          code: 'BAD_REQUEST',
          message: detail,
          status: status,
        );
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        final message = first is Map ? first['msg']?.toString() : null;
        return ApiException(
          code: 'VALIDATION',
          message: message ?? '입력값을 다시 확인해 주세요.',
          status: status,
        );
      }
    }

    return ApiException(
      code: 'UNKNOWN',
      message: switch (status ?? 0) {
        429 => '요청이 너무 잦아요. 잠시 후 다시 시도해 주세요.',
        // 5xx 는 에러 봉투 없이 Caddy 의 기본 HTML 이 오기도 한다 — 그때
        // "오류 502" 만 띄우면 쓰는 사람은 뭘 해야 할지 모른다
        >= 500 => '서버가 잠시 응답하지 못했어요. 잠시 후 다시 시도해 주세요. (오류 $status)',
        _ => '요청을 처리하지 못했어요. (오류 $status)',
      },
      status: status,
    );
  }

  @override
  String toString() => 'ApiException($status $code): $message';
}

/// 던져진 오류에서 사용자에게 보여줄 문장만 뽑는다
String messageOf(Object error) {
  if (error is ApiException) return error.message;
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  if (error is DioException) return ApiException.network(error.type).message;
  return '알 수 없는 오류가 발생했어요.';
}
