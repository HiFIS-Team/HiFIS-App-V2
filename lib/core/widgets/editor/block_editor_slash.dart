part of 'block_editor.dart';

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
              color: AppShadows.ink.withValues(alpha: 0.12),
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
