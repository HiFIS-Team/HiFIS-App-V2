import 'package:flutter/services.dart';

/// 메타 앱 ID — **여기에 넣는다.**
///
/// `developers.facebook.com` 에서 앱을 하나 만들고 받는 번호다. 비밀이 아니라
/// 앱 안에 그대로 박히는 값이라 `.env` 로 뺄 이유가 없다.
///
/// **비어 있으면 릴스로 안 보낸다** — 화면이 사진 앱 저장으로 떨어진다.
/// 인스타가 앱 ID 없이 온 요청을 그냥 무시해서, 안 넣고 부르면 **아무 일도
/// 안 일어난다.** 그게 제일 찾기 어려운 고장이라 아예 안 부른다.
const metaAppId = '';

/// 인스타그램 릴스로 영상 보내기 — **메타가 연 공식 길이다.**
///
/// 심사를 안 받는다. 앱을 하나 만들어 [metaAppId] 를 받고 대시보드에서
/// `Live` 로 켜면 끝이다 — 릴스 **발행** API(`instagram_content_publish`)와는
/// 다른 것이다. 저쪽은 서버가 대신 올리는 것이라 심사를 받아야 하고,
/// 이쪽은 **사람이 인스타 안에서 직접 올린다.**
///
/// ```
///   앱 [릴스로 올리기]  →  인스타 릴스 작성 화면 (영상이 이미 올라가 있다)
///                       →  사람이 캡션 쓰고 올린다
/// ```
///
/// | | 어떻게 |
/// |---|---|
/// | 애플 | `instagram-reels://share` + 붙임판(`com.instagram.sharedSticker.*`) |
/// | 안드로이드 | 인텐트 `com.instagram.share.ADD_TO_REEL` |
///
/// **영상 규격을 지켜야 받는다** — 3~60초 · 1080p · H.264 · 세로.
/// 우리 추첨 영상이 26~46초 · 1080×1920 · H.264 라 그대로 맞는다
/// (`tools/reels/render.mjs`).
class ReelsShare {
  static const _channel = MethodChannel('com.hifis/reels');

  /// 인스타로 넘긴다 — 공유 시트, 앱 ID 가 있으면 릴스 작성 화면으로 바로
  ///
  /// 돌려주는 값은 **열었나**지 올렸나가 아니다. 올리는 것은 사람이 인스타
  /// 안에서 한다.
  static Future<bool> share(String filePath) async {
    try {
      return await _channel.invokeMethod<bool>('share', {
            'path': filePath,
            'appId': metaAppId,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
