import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **앱이 서버 응답에서 읽는 필드가 실제로 오는 값인지** 대조한다.
///
/// 앱은 `lib/core/api/` 의 `fromJson` 68개에서 필드 이름을 **문자열로** 적는다.
/// 서버가 필드를 없애거나 이름을 바꾸거나 null 을 줄 수 있게 바꾸면
/// **컴파일에는 안 걸리고 그 화면을 열 때 터진다.** 실제로 서버 응답은 계속
/// 바뀌어 왔다 (`backend-gap.md` — `halfPeriod`·`allDay`·`todayAttendanceStatus`
/// 추가, `lastRank` 5칸→6칸 …). 그때마다 사람이 손으로 따라갔고 그물이 없었다.
///
/// 이 테스트는 **모델 하나하나에 손으로 쓰는 것이 없다.** Dart 소스에서
/// `json['x'] as T` 를 읽어 기대값을 뽑고, 서버 OpenAPI 스냅샷과 맞춰 본다.
/// 모델이 늘어도 저절로 대상에 들어간다.
///
/// ## 깨졌을 때
///
/// | 메시지 | 뜻 | 할 일 |
/// |---|---|---|
/// | 서버 스키마에 없다 | 필드가 없어졌거나 이름이 바뀌었다 | 앱의 필드 이름을 고친다 |
/// | required 가 아니다 | 서버가 안 줄 수도 있다 | `as T?` 로 받고 기본값을 준다 |
/// | null 이 올 수 있다 | 서버가 null 을 줄 수 있다 | 위와 같다 |
/// | 짝지을 스키마가 없다 | 새 모델이다 | 아래 [_explicit] 에 한 줄 넣는다 |
///
/// ## 스냅샷을 다시 받는 법
///
/// ```bash
/// tool/refresh_openapi.sh      # 로컬 서버(:8001)가 떠 있어야 한다
/// ```
///
/// 운영은 `/openapi.json` 을 닫아 두었다(404) — 그게 맞는 설정이라 **로컬에서
/// 받는다.** 그래서 스냅샷은 **개발 서버 기준**이고, 운영에 아직 안 올라간
/// 변경까지 들어 있을 수 있다. 그 방향은 안전하다(앱이 먼저 맞춰 두는 셈).
void main() {
  /// 이름으로 못 찾는 것만 적는다 — 나머지는 `X → XOut` 규칙으로 저절로 붙는다
  const explicit = <String, String>{
    'AppNotification': 'NotificationOut',
    'AttendanceRecord': 'AttendanceOut',
    'CalendarEvent': 'EventOut',
    'ChatAttachment': 'AttachmentOut',
    'ChatMessage': 'MessageOut',
    'FolderTreeResult': 'FolderTreeNodeOut',
    'Member': 'app__schemas__members__member__MemberOut',
    'MemberCreated': 'MemberCreateOut',
    'NoticeReader': 'NoticeReaderItem',
    'PostComment': 'CommentOut',
    'RankingRow': 'RankingBoardItem',
    'ScoreSummary': 'app__schemas__scoring__score__ScoreSummary',
    // 운동일지 — 표 두 줄은 서버도 이름이 그대로다(In·Out 을 안 나눴다)
    'WeightRow': 'WeightRow',
    'CardioRow': 'CardioRow',
    'MediaItem': 'MediaItemOut',
    'MediaGroup': 'MediaGroupOut',
    'WorkoutLog': 'WorkoutLogOut',
  };

  /// 서버 응답이 아닌 것 — 여기 있는 이름은 대조하지 않는다.
  /// **비우는 것이 기본이다.** 넣을 때는 왜 서버 응답이 아닌지 옆에 적는다.
  const notFromServer = <String, String>{};

  final spec =
      jsonDecode(File('test/fixtures/openapi.json').readAsStringSync())
          as Map<String, dynamic>;
  final schemas = (spec['schemas'] as Map).cast<String, dynamic>();

  final models = _readModels();

  test('모델을 하나도 못 읽으면 그게 고장이다', () {
    // 소스 모양이 바뀌어 정규식이 헛돌면 테스트가 **조용히 통과**한다.
    // 그게 제일 나쁜 결과라 하한을 둔다.
    expect(
      models.length,
      greaterThanOrEqualTo(60),
      reason: 'fromJson 을 ${models.length}개밖에 못 읽었다 — _readModels 를 확인한다',
    );
  });

  test('모든 모델이 서버 스키마와 짝이 맞는다', () {
    final orphans = [
      for (final name in models.keys)
        if (!notFromServer.containsKey(name) &&
            _schemaFor(name, explicit, schemas) == null)
          name,
    ];
    expect(
      orphans,
      isEmpty,
      reason:
          '짝지을 서버 스키마가 없다: $orphans\n'
          '  → 이름이 `XOut` 이 아니면 이 파일의 explicit 에 한 줄 넣는다.',
    );
  });

  for (final entry in models.entries) {
    final model = entry.key;
    if (notFromServer.containsKey(model)) continue;

    test('$model 이 읽는 필드가 서버 응답에 다 있다', () {
      final schemaName = _schemaFor(model, explicit, schemas);
      if (schemaName == null) return; // 위 테스트가 이미 잡는다
      final schema = (schemas[schemaName] as Map).cast<String, dynamic>();
      final required = ((schema['required'] as List).cast<String>()).toSet();
      final props = (schema['properties'] as Map).cast<String, dynamic>();

      final bad = <String>[];
      entry.value.forEach((field, nonNull) {
        if (!nonNull) return; // 앱이 이미 null 을 다루고 있다
        final prop = props[field];
        if (prop == null) {
          bad.add('$field — 서버 스키마($schemaName)에 없다');
        } else if (!required.contains(field)) {
          bad.add('$field — required 가 아니다 (안 올 수 있다)');
        } else if ((prop as Map)['nullable'] == true) {
          bad.add('$field — null 이 올 수 있다');
        }
      });

      expect(
        bad,
        isEmpty,
        reason:
            '$model ↔ $schemaName 이 어긋난다:\n'
            '${bad.map((b) => '    · $b').join('\n')}\n'
            '  → 앱에서 `as T?` 로 받고 기본값을 주거나, 필드 이름을 고친다.',
      );
    });
  }
}

/// `X` → `XOut` → `X` → `XResult` 순으로 찾는다
String? _schemaFor(
  String model,
  Map<String, String> explicit,
  Map<String, dynamic> schemas,
) {
  final named = explicit[model];
  if (named != null) return schemas.containsKey(named) ? named : null;
  for (final candidate in ['${model}Out', model, '${model}Result']) {
    if (schemas.containsKey(candidate)) return candidate;
  }
  return null;
}

/// `lib/core/api/` 를 훑어 `모델 → {필드: null 을 안 다루는가}` 를 만든다
///
/// 소스를 읽는 것이 미덥지 않아 보이지만, **모델마다 손으로 적는 것보다 낫다** —
/// 손으로 적으면 새 모델을 넣을 때 빠뜨리고, 빠뜨린 것은 아무도 모른다.
Map<String, Map<String, bool>> _readModels() {
  final out = <String, Map<String, bool>>{};
  final factories = RegExp(r'factory (\w+)\.fromJson\([^)]*\)\s*(?:=>|\{)');
  final reads = RegExp(r"json\['(\w+)'\]\s*as\s+[A-Za-z<>, ]+?(\?)?[\s,;)\]}]");
  final guards = RegExp(r"json\['(\w+)'\]\s*==\s*null");
  final stop = RegExp(r'\n\s*(factory |class |final |static )');

  for (final file in Directory('lib/core/api').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final text = file.readAsStringSync();
    for (final m in factories.allMatches(text)) {
      final rest = text.substring(m.end);
      final end = stop.firstMatch(rest);
      final body = rest.substring(0, end?.start ?? rest.length);

      final fields = out.putIfAbsent(m.group(1)!, () => <String, bool>{});
      for (final r in reads.allMatches(body)) {
        final name = r.group(1)!;
        // 같은 필드를 여러 번 읽으면 한 번이라도 non-null 이면 non-null 로 본다
        fields[name] = (fields[name] ?? true) && r.group(2) == null;
      }
      // `json['x'] == null ? … : …` 로 감쌌으면 앱이 null 을 다루는 것이다
      for (final g in guards.allMatches(body)) {
        fields[g.group(1)!] = false;
      }
    }
  }
  return out;
}
