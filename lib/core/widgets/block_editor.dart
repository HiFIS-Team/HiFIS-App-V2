import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 노션식 블록 편집기
///
/// 줄 하나가 블록 하나다. `# `, `- `, `- [ ] ` 처럼 기호를 치고 스페이스를 누르면
/// 기호는 사라지고 그 줄이 바로 제목·목록·체크박스로 바뀐다.
/// 저장은 마크다운 원문으로 돌려준다.
class BlockEditor extends StatefulWidget {
  BlockEditor({super.key, required this.source, required this.onChanged});

  final String source;

  /// 마크다운 원문
  final ValueChanged<String> onChanged;

  @override
  State<BlockEditor> createState() => BlockEditorState();
}

class BlockEditorState extends State<BlockEditor> {
  late final List<_Block> _blocks = _parse(widget.source);

  /// 명령어 메뉴가 열린 블록과 검색어
  _Block? _menuBlock;
  String _query = '';

  /// 방향키로 고르고 있는 명령어 번호
  int _menuIndex = 0;
  final _menuScroll = ScrollController();

  /// 고른 줄이 메뉴 밖으로 나가면 따라 스크롤하려고 잡아둔다
  final _menuRowKey = GlobalKey();

  final _link = LayerLink();

  @override
  void dispose() {
    for (final block in _blocks) {
      block.dispose();
    }
    _menuScroll.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(_serialize(_blocks));

  /// 위젯이 붙은 다음에 커서를 옮긴다 (새로 만든 블록은 아직 트리에 없다)
  void _focus(_Block block, {int? offset}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      block.focus.requestFocus();
      final at = offset ?? block.controller.text.length;
      block.controller.selection = TextSelection.collapsed(offset: at);
    });
  }

  // ── 입력 처리 ──

  void _onChanged(int index) {
    final block = _blocks[index];
    final text = block.controller.text;

    // 엔터는 줄바꿈 문자로 들어온다 — 그 자리에서 블록을 나눈다
    final br = text.indexOf('\n');
    if (br >= 0) {
      _enter(index, br);
      return;
    }

    // 기호 + 스페이스를 치면 바로 그 블록으로 바뀐다
    final shortcut = _shortcutOf(text);
    if (shortcut != null) {
      setState(() {
        block.type = shortcut.$1;
        block.controller.text = text.substring(shortcut.$2);
        block.controller.selection = TextSelection.collapsed(offset: 0);
        _menuBlock = null;
      });
      _emit();
      return;
    }

    setState(() => _updateMenu(block));
    _emit();
  }

  /// 줄바꿈이 들어온 지점에서 블록을 둘로 나눈다
  void _enter(int index, int br) {
    final block = _blocks[index];
    final text = block.controller.text;
    final before = text.substring(0, br);
    final after = text.substring(br + 1);

    // '---' 한 줄이면 구분선으로 바꾼다
    if (before.trim() == '---') {
      final next = _Block(text: after);
      setState(() {
        block.type = _BlockType.divider;
        block.controller.text = '';
        _blocks.insert(index + 1, next);
        _menuBlock = null;
      });
      _focus(next, offset: 0);
      _emit();
      return;
    }

    // 빈 목록·인용 블록에서 엔터를 치면 문단으로 되돌린다
    if (before.isEmpty && block.type != _BlockType.paragraph) {
      setState(() {
        block.type = _BlockType.paragraph;
        block.checked = false;
        block.controller.text = after;
        _menuBlock = null;
      });
      _focus(block, offset: 0);
      _emit();
      return;
    }

    final next = _Block(type: _inherit(block.type), text: after);
    setState(() {
      block.controller.text = before;
      _blocks.insert(index + 1, next);
      _menuBlock = null;
    });
    _focus(next, offset: 0);
    _emit();
  }

  /// 줄 맨 앞에서 백스페이스 — 블록 종류를 풀거나 앞 블록과 합친다
  void _backspace(int index) {
    final block = _blocks[index];

    if (block.type != _BlockType.paragraph) {
      setState(() {
        block.type = _BlockType.paragraph;
        block.checked = false;
      });
      _emit();
      return;
    }
    if (index == 0) return;

    final previous = _blocks[index - 1];
    if (previous.type == _BlockType.divider) {
      setState(() => _blocks.removeAt(index - 1));
      _retire(previous);
      _emit();
      return;
    }

    final offset = previous.controller.text.length;
    setState(() {
      previous.controller.text =
          previous.controller.text + block.controller.text;
      _blocks.removeAt(index);
    });
    _focus(previous, offset: offset);
    _retire(block);
    _emit();
  }

  /// 목록에서 빠진 블록 정리
  ///
  /// 바로 dispose하면 아직 화면에 남아 있는 TextField가 죽은 컨트롤러·포커스를
  /// 붙들고 있다가 깨져서, 앞줄로 커서가 안 넘어간다. 화면에서 지워진 뒤에 버린다.
  void _retire(_Block block) {
    WidgetsBinding.instance.addPostFrameCallback((_) => block.dispose());
  }

  // ── 슬래시 명령어 ──

  void _updateMenu(_Block block) {
    final wasOpen = _menuBlock != null;
    final before = _query;
    _refreshMenu(block);
    // 새로 열렸거나 검색어가 바뀌면 첫 줄부터 다시 고른다
    if (!wasOpen || _query != before) _menuIndex = 0;
  }

  void _refreshMenu(_Block block) {
    final text = block.controller.text;
    final cursor = block.controller.selection.baseOffset;
    if (cursor <= 0 || cursor > text.length) {
      _menuBlock = null;
      return;
    }

    var i = cursor - 1;
    while (i >= 0) {
      if (text[i] == '/') break;
      // 공백을 만나면 명령어가 아니다
      if (text[i] == ' ') {
        _menuBlock = null;
        return;
      }
      i--;
    }
    if (i < 0 || (i > 0 && text[i - 1] != ' ')) {
      _menuBlock = null;
      return;
    }

    _menuBlock = block;
    _query = text.substring(i + 1, cursor);
  }

  List<_Command> get _matches => _query.isEmpty
      ? _commands
      : _commands
            .where(
              (c) =>
                  c.label.contains(_query) ||
                  c.hint.startsWith(_query) ||
                  c.keyword.contains(_query.toLowerCase()),
            )
            .toList();

  /// 방향키로 위아래 이동 — 끝에서 한 번 더 누르면 반대쪽으로 돈다
  void _moveMenu(int delta) {
    final commands = _matches;
    if (commands.isEmpty) return;
    setState(() => _menuIndex = (_menuIndex + delta) % commands.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _menuRowKey.currentContext?.findRenderObject();
      if (target == null || !_menuScroll.hasClients) return;
      _menuScroll.position.ensureVisible(
        target,
        alignment: 0.5,
        duration: Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  /// 엔터로 지금 고른 명령어를 실행한다
  void _pickMenu() {
    final commands = _matches;
    final block = _menuBlock;
    if (block == null || commands.isEmpty) return;
    _run(block, commands[_menuIndex.clamp(0, commands.length - 1)]);
  }

  /// 고른 명령어 적용 — '/검색어'는 지우고 블록 종류를 바꾼다
  void _run(_Block block, _Command command) {
    final text = block.controller.text;
    final cursor = block.controller.selection.baseOffset.clamp(0, text.length);
    final start = (cursor - _query.length - 1).clamp(0, text.length);
    final stripped = text.replaceRange(start, cursor, '');
    final index = _blocks.indexOf(block);

    setState(() {
      _menuBlock = null;
      block.controller.text = stripped;

      switch (command.type) {
        case _Type.block:
          block.type = command.block!;
          if (command.block == _BlockType.divider) {
            // 구분선 뒤에는 이어서 쓸 빈 줄을 하나 둔다
            final next = _Block(text: stripped);
            block.controller.text = '';
            _blocks.insert(index + 1, next);
            _focus(next, offset: 0);
          } else {
            _focus(block, offset: start);
          }
        case _Type.wrap:
          // 인라인 기호는 글자 사이에 커서를 둔다
          block.controller.text = stripped.replaceRange(
            start,
            start,
            '${command.token}${command.token}',
          );
          _focus(block, offset: start + command.token.length);
      }
    });
    _emit();
  }

  // ── 그리기 ──

  @override
  Widget build(BuildContext context) {
    if (_blocks.isEmpty) _blocks.add(_Block());

    final commands = _matches;
    final menuOpen = _menuBlock != null && commands.isNotEmpty;
    final menuIndex = menuOpen ? _menuIndex.clamp(0, commands.length - 1) : 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.gray20,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _blocks.length; i++)
            _BlockRow(
              // 줄이 지워지거나 끼어들어도 칸과 커서가 서로 엉키지 않게 한다
              key: ValueKey(_blocks[i]),
              block: _blocks[i],
              number: _numberOf(i),
              // 처음이자 비어 있는 블록에만 안내를 띄운다
              hint: _blocks.length == 1 && _blocks[i].controller.text.isEmpty
                  ? "'/'를 입력하면 명령어가 나와요"
                  : null,
              link: _blocks[i] == _menuBlock ? _link : null,
              menuOpen: menuOpen && _blocks[i] == _menuBlock,
              onMenuMove: _moveMenu,
              onMenuPick: _pickMenu,
              onMenuClose: () => setState(() => _menuBlock = null),
              onChanged: () => _onChanged(i),
              onBackspace: () => _backspace(i),
              onCheck: () {
                setState(() => _blocks[i].checked = !_blocks[i].checked);
                _emit();
              },
              onTap: () => setState(() => _menuBlock = null),
            ),
          // 아래 빈 곳을 눌러도 마지막 줄에 커서가 간다.
          //
          // **얇게 둔다.** 예전엔 120 이었는데, 그러면 두어 줄만 적어도
          // 상자가 화면 아래까지 내려가 있어서 "쓰기도 전에 커 보인다".
          // 줄을 더할수록 상자가 자라는 게 보이는 편이 낫다.
          // 마지막 줄 바로 아래를 누르려는 것이라 이 정도면 닿는다.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _focus(_blocks.last),
            child: SizedBox(height: 28, width: double.infinity),
          ),
          if (menuOpen)
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: Offset(0, 4),
              child: Align(
                alignment: Alignment.topLeft,
                child: _SlashMenu(
                  commands: commands,
                  selected: menuIndex,
                  selectedKey: _menuRowKey,
                  controller: _menuScroll,
                  // 마우스를 올린 줄이 곧 엔터로 실행될 줄이 되게 맞춘다
                  onHover: (i) => setState(() => _menuIndex = i),
                  onPick: (command) => _run(_menuBlock!, command),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 번호 목록은 위로 이어지는 번호 블록을 세어 번호를 매긴다
  int _numberOf(int index) {
    if (_blocks[index].type != _BlockType.numbered) return 0;
    var number = 1;
    for (var i = index - 1; i >= 0; i--) {
      if (_blocks[i].type != _BlockType.numbered) break;
      number++;
    }
    return number;
  }
}

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

/// 커서 아래에 뜨는 '/' 명령어 메뉴
class _SlashMenu extends StatelessWidget {
  _SlashMenu({
    required this.commands,
    required this.selected,
    required this.selectedKey,
    required this.controller,
    required this.onHover,
    required this.onPick,
  });

  final List<_Command> commands;

  /// 방향키로 고르고 있는 줄 (마우스를 올려도 여기로 옮겨간다)
  final int selected;
  final Key selectedKey;
  final ScrollController controller;
  final ValueChanged<int> onHover;
  final ValueChanged<_Command> onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 260,
        constraints: BoxConstraints(maxHeight: 300),
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          controller: controller,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < commands.length; i++)
                _CommandRow(
                  key: i == selected ? selectedKey : null,
                  command: commands[i],
                  selected: i == selected,
                  onHover: () => onHover(i),
                  onTap: () => onPick(commands[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  _CommandRow({
    super.key,
    required this.command,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  final _Command command;

  /// 지금 골라져 있는 줄 (방향키·마우스가 같은 표시를 쓴다)
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : AppColors.gray50,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  command.icon,
                  size: 15,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  command.label,
                  style: AppTextStyles.body2.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primary : null,
                  ),
                ),
              ),
              Text(
                command.hint,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontFamily: 'Menlo',
                  fontFamilyFallback: ['monospace'],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 마크다운 문법 도움말 (달력 옆 버튼으로 펼친다)
class MarkdownHelpPanel extends StatelessWidget {
  MarkdownHelpPanel({super.key});

  static const _rows = [
    ('/', '명령어 메뉴 열기'),
    ('# ', '제목'),
    ('## ', '소제목'),
    ('### ', '작은 제목'),
    ('- ', '글머리 목록'),
    ('1. ', '번호 목록'),
    ('- [ ] ', '체크박스'),
    ('> ', '인용'),
    ('---', '구분선'),
    ('**굵게**', '굵은 글씨'),
    ('*기울임*', '기울임'),
    ('`코드`', '인라인 코드'),
    ('~~취소~~', '취소선'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.gray20,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        children: [
          for (final (token, label) in _rows)
            SizedBox(
              width: 190,
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.gray100),
                    ),
                    child: Text(
                      token,
                      style: TextStyle(
                        fontFamily: 'Menlo',
                        fontFamilyFallback: ['monospace'],
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 참석자 고르는 알약
// ── 슬래시 명령어 목록 ──

/// 명령어가 본문에 적용되는 방식
enum _Type {
  /// 블록 종류를 바꾼다
  block,

  /// 인라인 기호로 감싼다
  wrap,
}

class _Command {
  const _Command({
    required this.label,
    required this.hint,
    required this.keyword,
    required this.icon,
    required this.type,
    this.block,
    this.token = '',
  });

  final String label;

  /// 오른쪽에 보여줄 마크다운 기호
  final String hint;

  /// 영문으로 쳐도 걸리게 하는 검색어
  final String keyword;
  final IconData icon;
  final _Type type;

  /// block 방식일 때 바뀔 종류
  final _BlockType? block;

  /// wrap 방식일 때 감쌀 기호
  final String token;
}

const _commands = [
  _Command(
    label: '제목',
    hint: '#',
    keyword: 'h1 title',
    icon: Icons.title_rounded,
    type: _Type.block,
    block: _BlockType.h1,
  ),
  _Command(
    label: '소제목',
    hint: '##',
    keyword: 'h2',
    icon: Icons.title_rounded,
    type: _Type.block,
    block: _BlockType.h2,
  ),
  _Command(
    label: '작은 제목',
    hint: '###',
    keyword: 'h3',
    icon: Icons.title_rounded,
    type: _Type.block,
    block: _BlockType.h3,
  ),
  _Command(
    label: '글머리 목록',
    hint: '-',
    keyword: 'list bullet',
    icon: Icons.format_list_bulleted_rounded,
    type: _Type.block,
    block: _BlockType.bullet,
  ),
  _Command(
    label: '번호 목록',
    hint: '1.',
    keyword: 'number ol',
    icon: Icons.format_list_numbered_rounded,
    type: _Type.block,
    block: _BlockType.numbered,
  ),
  _Command(
    label: '체크박스',
    hint: '[]',
    keyword: 'todo check',
    icon: Icons.checklist_rounded,
    type: _Type.block,
    block: _BlockType.todo,
  ),
  _Command(
    label: '인용',
    hint: '>',
    keyword: 'quote',
    icon: Icons.format_quote_rounded,
    type: _Type.block,
    block: _BlockType.quote,
  ),
  _Command(
    label: '구분선',
    hint: '---',
    keyword: 'divider line hr',
    icon: Icons.horizontal_rule_rounded,
    type: _Type.block,
    block: _BlockType.divider,
  ),
  _Command(
    label: '문단',
    hint: 'p',
    keyword: 'text paragraph',
    icon: Icons.notes_rounded,
    type: _Type.block,
    block: _BlockType.paragraph,
  ),
  _Command(
    label: '굵게',
    hint: '**',
    keyword: 'bold',
    icon: Icons.format_bold_rounded,
    type: _Type.wrap,
    token: '**',
  ),
  _Command(
    label: '인라인 코드',
    hint: '`',
    keyword: 'code',
    icon: Icons.code_rounded,
    type: _Type.wrap,
    token: '`',
  ),
];
