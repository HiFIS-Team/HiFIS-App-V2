import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 간단한 마크다운 뷰어
///
/// 회의록·공지처럼 직원이 직접 적는 글에 필요한 문법만 다룬다.
/// 외부 패키지 대신 직접 그려서 앱 타이포그래피(AppTextStyles)를 그대로 쓴다.
///
/// 지원: `#`~`###` 제목, `-`/`*` 목록(들여쓰기), `1.` 번호 목록,
/// `- [ ]`/`- [x]` 체크박스, `>` 인용, `---` 구분선, ``` 코드 블록,
/// 인라인 `**굵게**` `*기울임*` `` `코드` `` `~~취소선~~`.
class MarkdownView extends StatelessWidget {
  MarkdownView({super.key, required this.source, this.onCheckbox});

  final String source;

  /// 체크박스를 누르면 원문 몇 번째 줄이 어떻게 바뀌어야 하는지 알려준다.
  /// 넘기지 않으면 체크박스는 읽기 전용이다.
  final void Function(int line, bool checked)? onCheckbox;

  static final _bullet = RegExp(r'^(\s*)[-*]\s+(.*)$');
  static final _checkbox = RegExp(r'^(\s*)[-*]\s+\[([ xX])\]\s*(.*)$');
  static final _ordered = RegExp(r'^(\s*)(\d+)\.\s+(.*)$');
  static final _heading = RegExp(r'^(#{1,3})\s+(.*)$');

  @override
  Widget build(BuildContext context) {
    final lines = source.split('\n');
    final blocks = <Widget>[];
    final code = <String>[];
    var inCode = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 코드 블록은 닫힐 때까지 통째로 모은다
      if (line.trimLeft().startsWith('```')) {
        if (inCode) {
          blocks.add(_CodeBlock(text: code.join('\n')));
          code.clear();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        code.add(line);
        continue;
      }

      if (line.trim().isEmpty) {
        blocks.add(SizedBox(height: 10));
        continue;
      }
      if (line.trim() == '---' || line.trim() == '***') {
        blocks.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Container(height: 1, color: AppColors.gray100),
          ),
        );
        continue;
      }

      final heading = _heading.firstMatch(line);
      if (heading != null) {
        final level = heading[1]!.length;
        blocks.add(
          Padding(
            padding: EdgeInsets.only(top: level == 1 ? 14 : 12, bottom: 6),
            child: Text.rich(
              TextSpan(
                children: _inline(
                  heading[2]!,
                  level == 1
                      ? AppTextStyles.title2
                      : level == 2
                      ? AppTextStyles.title3
                      : AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final checkbox = _checkbox.firstMatch(line);
      if (checkbox != null) {
        final checked = checkbox[2]!.toLowerCase() == 'x';
        blocks.add(
          _CheckRow(
            indent: checkbox[1]!.length ~/ 2,
            checked: checked,
            spans: _inline(
              checkbox[3]!,
              AppTextStyles.body2.copyWith(
                color: checked ? AppColors.textTertiary : AppColors.textPrimary,
                decoration: checked ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.gray400,
              ),
            ),
            onTap: onCheckbox == null ? null : () => onCheckbox!(i, !checked),
          ),
        );
        continue;
      }

      final bullet = _bullet.firstMatch(line);
      if (bullet != null) {
        blocks.add(
          _ListRow(
            indent: bullet[1]!.length ~/ 2,
            marker: '•',
            spans: _inline(bullet[2]!, AppTextStyles.body2),
          ),
        );
        continue;
      }

      final ordered = _ordered.firstMatch(line);
      if (ordered != null) {
        blocks.add(
          _ListRow(
            indent: ordered[1]!.length ~/ 2,
            marker: '${ordered[2]}.',
            spans: _inline(ordered[3]!, AppTextStyles.body2),
          ),
        );
        continue;
      }

      if (line.trimLeft().startsWith('> ')) {
        blocks.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Container(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.gray200, width: 3),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  children: _inline(
                    line.trimLeft().substring(2),
                    AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      blocks.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: 3),
          child: Text.rich(
            TextSpan(children: _inline(line, AppTextStyles.body2)),
          ),
        ),
      );
    }

    // 닫히지 않은 코드 블록도 살려서 보여준다
    if (code.isNotEmpty) blocks.add(_CodeBlock(text: code.join('\n')));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
}

final _inlinePattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`([^`]+)`|~~(.+?)~~');

/// 한 줄 안의 굵게·기울임·코드·취소선을 스타일로 바꾼다
List<InlineSpan> _inline(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  var index = 0;

  for (final match in _inlinePattern.allMatches(text)) {
    if (match.start > index) {
      spans.add(
        TextSpan(text: text.substring(index, match.start), style: base),
      );
    }
    if (match[1] != null) {
      spans.add(
        TextSpan(
          text: match[1],
          style: base.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    } else if (match[2] != null) {
      spans.add(
        TextSpan(
          text: match[2],
          style: base.copyWith(fontStyle: FontStyle.italic),
        ),
      );
    } else if (match[3] != null) {
      spans.add(
        TextSpan(
          text: match[3],
          style: base.copyWith(
            fontFamily: 'Menlo',
            fontFamilyFallback: ['monospace'],
            fontSize: (base.fontSize ?? 15) - 1,
            backgroundColor: AppColors.gray50,
            color: AppColors.primary,
          ),
        ),
      );
    } else if (match[4] != null) {
      spans.add(
        TextSpan(
          text: match[4],
          style: base.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: AppColors.gray400,
            color: AppColors.textTertiary,
          ),
        ),
      );
    }
    index = match.end;
  }
  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index), style: base));
  }
  return spans;
}

/// 목록 한 줄 (글머리표 또는 번호)
class _ListRow extends StatelessWidget {
  _ListRow({required this.indent, required this.marker, required this.spans});

  final int indent;
  final String marker;
  final List<InlineSpan> spans;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent * 18.0, top: 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              marker,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(child: Text.rich(TextSpan(children: spans))),
        ],
      ),
    );
  }
}

/// 체크박스 한 줄 — 누르면 원문이 바뀐다
class _CheckRow extends StatelessWidget {
  _CheckRow({
    required this.indent,
    required this.checked,
    required this.spans,
    this.onTap,
  });

  final int indent;
  final bool checked;
  final List<InlineSpan> spans;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent * 18.0, top: 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: onTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: 18,
                height: 18,
                margin: EdgeInsets.only(top: 3, right: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: checked ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: checked ? AppColors.primary : AppColors.gray300,
                    width: 1.5,
                  ),
                ),
                child: checked
                    ? Icon(Icons.check_rounded, size: 12, color: Colors.white)
                    : null,
              ),
            ),
          ),
          Expanded(child: Text.rich(TextSpan(children: spans))),
        ],
      ),
    );
  }
}

/// 코드 블록
class _CodeBlock extends StatelessWidget {
  _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Menlo',
            fontFamilyFallback: ['monospace'],
            fontSize: 13,
            height: 1.6,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
