import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hifis_app/core/util/keep_words.dart';

/// 한글 할 일이 낱말 가운데서 안 꺾이게 — 이음표를 낱말 **안에만** 넣는다
void main() {
  test('낱말 안 글자 사이에만 이음표가 들어가고 띄어쓰기는 그대로다', () {
    expect(keepWords('비교표 만들기'), '비⁠교⁠표 만⁠들⁠기');
  });

  test('이음표를 빼면 원래 글과 같다 — 보이는 글자는 안 바뀐다', () {
    const text = '3층 스트레칭존  매트 교체\n견적 받기';
    expect(keepWords(text).replaceAll('⁠', ''), text);
  });

  test('한 글자 낱말·빈 글은 손대지 않는다', () {
    expect(keepWords('a b'), 'a b');
    expect(keepWords(''), '');
  });

  test('이모지는 반으로 안 갈린다 — 보이는 글자 단위로 나눈다', () {
    // 피부색이 붙은 엄지 = 코드 단위 4개. 그 사이에 끼우면 깨진 글자가 된다
    expect(keepWords('👍🏻👍🏻'), '👍🏻⁠👍🏻');
    expect(keepWords('완료👨‍👩‍👧'), '완⁠료⁠👨‍👩‍👧');
  });

  testWidgets('한 줄보다 긴 낱말은 넘치지 않고 줄을 바꾼다', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 120,
            child: Text(
              keepWords('가' * 60),
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // 한 줄(22.5)에 다 들어갈 수 없는 길이 — 여러 줄로 섰어야 한다
    expect(tester.getSize(find.byType(Text)).width, lessThanOrEqualTo(120));
    expect(tester.getSize(find.byType(Text)).height, greaterThan(45));
  });
}
