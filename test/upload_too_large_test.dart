import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifis_app/core/api/client/api_exception.dart';

/// 앞단 nginx 가 본문을 자르면 **우리 에러 봉투가 없는 답**이 온다.
///
/// 운동일지 영상이 안 올라가던 것을 한참 헤맨 이유가 이거다 — nginx 기본
/// HTML 이 413 으로 오는데 앱은 "요청을 처리하지 못했어요. (오류 413)" 만
/// 띄워서, 쓰는 사람도 고치는 사람도 용량 문제인 줄 몰랐다.
void main() {
  Response<dynamic> nginxError(int status, String html) => Response<dynamic>(
    requestOptions: RequestOptions(path: '/workouts/media'),
    statusCode: status,
    data: html,
  );

  test('nginx 413 은 용량 문제라고 읽히는 문장이 된다', () {
    final error = ApiException.fromResponse(
      nginxError(413, '<html><head><title>413 Request Entity Too Large</title>'
          '</head><body><center><h1>413 Request Entity Too Large</h1></center>'
          '<hr><center>nginx</center></body></html>'),
    );
    expect(error.status, 413);
    expect(error.message, contains('너무 커'));
    // 숫자를 안 적는다 — 한계는 nginx 설정에 있다 (`ops/nginx-upload.conf`)
    expect(error.message, isNot(contains('MB')));
  });

  test('우리 봉투가 있으면 서버 문장을 그대로 쓴다', () {
    final response = Response<dynamic>(
      requestOptions: RequestOptions(path: '/workouts/media'),
      statusCode: 400,
      data: {
        'detail': {'code': 'MEDIA_TOO_LARGE', 'message': '영상은 100MB 이하만 올릴 수 있습니다'},
      },
    );
    expect(ApiException.fromResponse(response).message, '영상은 100MB 이하만 올릴 수 있습니다');
  });
}
