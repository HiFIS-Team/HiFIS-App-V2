import 'package:flutter/widgets.dart' show StringCharacters;

/// 한글을 **띄어쓰기에서만** 줄 바꾸게 한다 (CSS `word-break: keep-all`)
///
/// Flutter 는 한글을 글자마다 끊는다 — 긴 할 일이 `비교표 만들` / `기` 처럼
/// 낱말 가운데서 꺾였다 (2026-11-02). 낱말 안 글자 사이에 **단어 이음표**
/// (U+2060, 보이지 않는다)를 끼워 거기서는 못 끊게 한다.
///
/// 글자는 **보이는 글자 단위**(`characters`)로 나눈다. 코드 단위로 나누면
/// 이모지(`👍🏻`)·자모가 반으로 갈려 깨진다.
///
/// 한 낱말이 한 줄보다 길면 그래도 끊긴다 — 넘치는 것보다 낫다.
/// **화면에 그릴 글에만 쓴다.** 저장·검색·비교하는 값에 넣으면 같은 글이
/// 다른 글이 된다.
String keepWords(String text) => text.replaceAllMapped(
  RegExp(r'\S{2,}'),
  (m) => m[0]!.characters.join('⁠'),
);
