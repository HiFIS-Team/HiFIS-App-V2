import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_shadows.dart';
part 'block_editor_row.dart';
part 'block_editor_slash.dart';

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
