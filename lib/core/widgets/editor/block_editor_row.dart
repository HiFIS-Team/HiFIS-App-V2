part of 'block_editor.dart';

/// 블록 한 줄 — 종류에 맞는 글꼴과 앞머리(글머리표·번호·체크박스)를 붙인다
class _BlockRow extends StatelessWidget {
  _BlockRow({
    super.key,
    required this.block,
    required this.number,
    required this.hint,
    required this.link,
    required this.menuOpen,
    required this.onMenuMove,
    required this.onMenuPick,
    required this.onMenuClose,
    required this.onChanged,
    required this.onBackspace,
    required this.onCheck,
    required this.onTap,
  });

  final _Block block;
  final int number;
  final String? hint;

  /// 명령어 메뉴가 이 블록에 붙어 있으면 위치 기준을 잡아준다
  final LayerLink? link;

  /// 이 줄에 명령어 메뉴가 떠 있으면 방향키·엔터를 메뉴가 먼저 가져간다
  final bool menuOpen;
  final ValueChanged<int> onMenuMove;
  final VoidCallback onMenuPick;
  final VoidCallback onMenuClose;
  final VoidCallback onChanged;
  final VoidCallback onBackspace;
  final VoidCallback onCheck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (block.type == _BlockType.divider) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Container(height: 1, color: AppColors.gray200),
      );
    }

    final done = block.type == _BlockType.todo && block.checked;
    final style = switch (block.type) {
      _BlockType.h1 => AppTextStyles.title2,
      _BlockType.h2 => AppTextStyles.title3,
      _BlockType.h3 => AppTextStyles.body1.copyWith(
        fontWeight: FontWeight.w700,
      ),
      _BlockType.quote => AppTextStyles.body2.copyWith(
        height: 1.7,
        color: AppColors.textSecondary,
      ),
      _ => AppTextStyles.body2.copyWith(
        height: 1.7,
        color: done ? AppColors.textTertiary : AppColors.textPrimary,
        decoration: done ? TextDecoration.lineThrough : null,
        decorationColor: AppColors.gray400,
      ),
    };

    final field = Focus(
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;

        // 명령어 메뉴가 떠 있으면 방향키로 고르고 엔터로 실행한다.
        // 여기서 handled로 끊어야 엔터가 줄바꿈으로 들어가지 않는다.
        if (menuOpen) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            onMenuMove(1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            onMenuMove(-1);
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) {
              onMenuPick();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              onMenuClose();
              return KeyEventResult.handled;
            }
          }
        }

        // 줄 맨 앞에서 백스페이스를 누르면 종류를 풀거나 앞줄과 합친다.
        // 누르고 있는 동안 오는 반복 신호는 무시한다 (한 번에 여러 줄이 합쳐진다)
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey != LogicalKeyboardKey.backspace) {
          return KeyEventResult.ignored;
        }
        final selection = block.controller.selection;
        if (!selection.isCollapsed || selection.baseOffset != 0) {
          return KeyEventResult.ignored;
        }
        onBackspace();
        return KeyEventResult.handled;
      },
      child: TextField(
        controller: block.controller,
        focusNode: block.focus,
        style: style,
        cursorColor: AppColors.primary,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        onChanged: (_) => onChanged(),
        onTap: onTap,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: style.copyWith(color: AppColors.gray400),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: block.type == _BlockType.h1 || block.type == _BlockType.h2
            ? 10
            : 3,
        bottom: 3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.type == _BlockType.quote)
            Container(
              width: 3,
              height: 22,
              margin: EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (block.type == _BlockType.bullet)
            SizedBox(
              width: 20,
              child: Text(
                '•',
                style: AppTextStyles.body2.copyWith(
                  height: 1.7,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          if (block.type == _BlockType.numbered)
            SizedBox(
              width: 22,
              child: Text(
                '$number.',
                style: AppTextStyles.body2.copyWith(
                  height: 1.7,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          if (block.type == _BlockType.todo)
            Padding(
              padding: EdgeInsets.only(right: 10, top: 4),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onCheck,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: block.checked
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: block.checked
                            ? AppColors.primary
                            : AppColors.gray300,
                        width: 1.5,
                      ),
                    ),
                    child: block.checked
                        ? Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          Expanded(
            child: link == null
                ? field
                : CompositedTransformTarget(link: link!, child: field),
          ),
        ],
      ),
    );
  }
}

/// 편집기의 블록 한 개
class _Block {
  _Block({
    this.type = _BlockType.paragraph,
    String text = '',
    this.checked = false,
  }) : controller = TextEditingController(text: text);

  _BlockType type;
  bool checked;
  final TextEditingController controller;
  final FocusNode focus = FocusNode();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

enum _BlockType {
  paragraph,
  h1,
  h2,
  h3,
  bullet,
  numbered,
  todo,
  quote,
  divider,
}

/// 엔터를 쳤을 때 새 블록이 물려받을 종류 (목록은 이어지고 나머지는 문단)
_BlockType _inherit(_BlockType type) => switch (type) {
  _BlockType.bullet || _BlockType.numbered || _BlockType.todo => type,
  _ => _BlockType.paragraph,
};

/// 기호 + 스페이스 단축 입력 — (바뀔 종류, 지울 글자 수)
(_BlockType, int)? _shortcutOf(String text) {
  const shortcuts = {
    '# ': _BlockType.h1,
    '## ': _BlockType.h2,
    '### ': _BlockType.h3,
    '- ': _BlockType.bullet,
    '* ': _BlockType.bullet,
    '1. ': _BlockType.numbered,
    '[] ': _BlockType.todo,
    '[ ] ': _BlockType.todo,
    '> ': _BlockType.quote,
  };
  for (final entry in shortcuts.entries) {
    if (text.startsWith(entry.key)) return (entry.value, entry.key.length);
  }
  return null;
}

/// 마크다운 원문 → 블록
List<_Block> _parse(String source) {
  final blocks = <_Block>[];
  for (final line in source.split('\n')) {
    final trimmed = line.trimRight();
    if (trimmed.trim() == '---') {
      blocks.add(_Block(type: _BlockType.divider));
      continue;
    }
    final checkbox = RegExp(r'^\s*[-*]\s+\[([ xX])\]\s*(.*)$').firstMatch(line);
    if (checkbox != null) {
      blocks.add(
        _Block(
          type: _BlockType.todo,
          text: checkbox[2]!,
          checked: checkbox[1]!.toLowerCase() == 'x',
        ),
      );
      continue;
    }
    final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      blocks.add(
        _Block(
          type: switch (heading[1]!.length) {
            1 => _BlockType.h1,
            2 => _BlockType.h2,
            _ => _BlockType.h3,
          },
          text: heading[2]!,
        ),
      );
      continue;
    }
    final ordered = RegExp(r'^\s*\d+\.\s+(.*)$').firstMatch(line);
    if (ordered != null) {
      blocks.add(_Block(type: _BlockType.numbered, text: ordered[1]!));
      continue;
    }
    final bullet = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      blocks.add(_Block(type: _BlockType.bullet, text: bullet[1]!));
      continue;
    }
    if (line.trimLeft().startsWith('> ')) {
      blocks.add(
        _Block(type: _BlockType.quote, text: line.trimLeft().substring(2)),
      );
      continue;
    }
    blocks.add(_Block(text: trimmed));
  }
  if (blocks.isEmpty) blocks.add(_Block());
  return blocks;
}

/// 블록 → 마크다운 원문 (저장·읽기 모드에서 쓴다)
String _serialize(List<_Block> blocks) {
  var number = 0;
  final lines = <String>[];
  for (final block in blocks) {
    final text = block.controller.text;
    number = block.type == _BlockType.numbered ? number + 1 : 0;
    lines.add(switch (block.type) {
      _BlockType.h1 => '# $text',
      _BlockType.h2 => '## $text',
      _BlockType.h3 => '### $text',
      _BlockType.bullet => '- $text',
      _BlockType.numbered => '$number. $text',
      _BlockType.todo => '- [${block.checked ? 'x' : ' '}] $text',
      _BlockType.quote => '> $text',
      _BlockType.divider => '---',
      _BlockType.paragraph => text,
    });
  }
  return lines.join('\n');
}
