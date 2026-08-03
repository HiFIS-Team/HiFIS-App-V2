import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifis_app/core/util/rich_blocks.dart';

/// 회의록 본문은 앱에서는 마크다운, 서버에서는 블록 트리다.
/// 오갈 때 내용이 새지 않는지 본다.
void main() {
  const source = '''
## 안건

1. 지난주 매출 리뷰
2. 여름 이벤트

## 논의

- 신규 등록 **18건**, `62%`
- ~~취소선~~ 과 *기울임*

> 경품 단가를 낮추자는 의견

- [x] 포스터 확정
- [ ] 예약 발행''';

  test('마크다운 → 블록 → 마크다운 이 내용을 지키고, 한 번 더 돌려도 그대로다', () {
    final once = markdownFromBlocks(blocksFromMarkdown(source));
    // 빈 줄 자리는 블록 사이 한 줄로 정리된다 — 글자는 그대로여야 한다
    expect(
      once.replaceAll(RegExp(r'\n+'), '\n'),
      source.replaceAll(RegExp(r'\n+'), '\n'),
    );

    // 두 번째부터는 완전히 같아야 한다 (열 때마다 본문이 바뀌면 안 된다)
    final twice = markdownFromBlocks(blocksFromMarkdown(once));
    expect(twice, once);
  });

  test('굵게·기울임·코드·취소선이 마크로 갔다가 돌아온다', () {
    final blocks = blocksFromMarkdown('**굵게** *기울임* `코드` ~~취소~~');
    final marks =
        ((blocks.first['content'] as List)
                .map((n) => ((n as Map)['marks'] as List?)?.first)
                .whereType<Map>()
                .map((m) => m['type']))
            .toList();
    expect(marks, ['bold', 'italic', 'code', 'strike']);
    expect(markdownFromBlocks(blocks), '**굵게** *기울임* `코드` ~~취소~~');
  });

  test('체크박스가 글머리로 잘못 잡히지 않는다', () {
    final blocks = blocksFromMarkdown('- [x] 완료\n- [ ] 아직\n- 그냥 글머리');
    expect(blocks.map((b) => b['type']), ['taskList', 'bulletList']);
    final items = blocks.first['content'] as List;
    expect((items[0] as Map)['attrs'], {'checked': true});
    expect((items[1] as Map)['attrs'], {'checked': false});
  });

  test('서버에 이미 쌓인 블록을 읽는다', () {
    // 웹에서 쓴 회의록 한 건의 실제 모양
    final blocks =
        jsonDecode('''
[{"type":"heading","attrs":{"level":2},"content":[{"text":"브레인 스토밍","type":"text"}]},
 {"type":"bulletList","content":[{"type":"listItem","content":[
   {"type":"paragraph","content":[{"text":"ㅎㅇ","type":"text"}]}]}]},
 {"type":"paragraph","content":[{"text":"굵게","type":"text","marks":[{"type":"bold"}]}]}]
''')
            as List<dynamic>;
    expect(markdownFromBlocks(blocks), '## 브레인 스토밍\n\n- ㅎㅇ\n\n**굵게**');
  });

  test('모르는 블록이 와도 글자는 살린다', () {
    final blocks =
        jsonDecode(
              '[{"type":"table","content":[{"type":"cell","content":[{"text":"값","type":"text"}]}]}]',
            )
            as List<dynamic>;
    expect(markdownFromBlocks(blocks), '값');
  });

  test('빈 본문은 빈 블록이 되고 되돌아온다', () {
    expect(blocksFromMarkdown(''), isEmpty);
    expect(markdownFromBlocks(const []), '');
  });
}
