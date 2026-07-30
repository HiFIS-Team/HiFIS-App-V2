import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/action_pill.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/block_editor.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/markdown_view.dart';
import '../../core/widgets/pressable.dart';

part 'meeting_phone.dart';

/// 회의록 화면 (목업)
///
/// 데스크톱은 좌측 목록 + 우측 본문 2단 구조.
/// 폰은 같은 내용을 목록 화면 + 본문 화면 두 장으로 나눠 보여준다.
/// 본문은 마크다운으로 적고, 평소에는 렌더링된 모습으로 읽는다.
class MeetingScreen extends StatefulWidget {
  MeetingScreen({super.key});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  _Note? _selected;

  /// 새로 만든 회의록은 바로 편집 모드로 연다
  bool _startEditing = false;

  List<_Note> get _sorted =>
      [..._notes]..sort((a, b) => b.date.compareTo(a.date));

  _Note? _syncSelection(List<_Note> list) {
    if (list.isEmpty) return null;
    if (_selected != null && list.contains(_selected)) return _selected;
    return list.first;
  }

  void _create() {
    final now = DateTime.now();
    final note = _Note(
      title: '',
      date: DateTime(now.year, now.month, now.day),
      members: [me],
      body: '',
      updated: now,
    );
    setState(() {
      _notes.add(note);
      _selected = note;
      _startEditing = true;
    });
  }

  void _delete(_Note note) {
    setState(() {
      _notes.remove(note);
      _selected = null;
    });
    AppToast.show(context, '회의록을 삭제했어요');
  }

  @override
  Widget build(BuildContext context) {
    final list = _sorted;

    if (!isDesktop) {
      return _MeetingPhone(notes: list, onChanged: () => setState(() {}));
    }

    final selected = _syncSelection(list);

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 320,
            child: ColoredBox(
              color: AppColors.surface,
              child: _NoteList(
                notes: list,
                selected: selected,
                onSelect: (note) => setState(() {
                  _selected = note;
                  _startEditing = false;
                }),
                onCreate: _create,
              ),
            ),
          ),
          Container(width: 1, color: AppColors.gray100),
          Expanded(
            child: selected == null
                ? _EmptyNote(onCreate: _create)
                : _NoteView(
                    // 회의록을 바꾸면 편집 상태·스크롤을 새로 시작한다
                    key: ValueKey(selected),
                    note: selected,
                    editing: _startEditing,
                    onChanged: () => setState(() {}),
                    onDelete: () => _delete(selected),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 좌측 목록 ──

class _NoteList extends StatelessWidget {
  _NoteList({
    required this.notes,
    required this.selected,
    required this.onSelect,
    required this.onCreate,
  });

  final List<_Note> notes;
  final _Note? selected;
  final ValueChanged<_Note> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 글래스 헤더 버튼 영역만큼 비워둔다
        SizedBox(height: 64),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Text('회의록', style: AppTextStyles.title2),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${notes.length}',
                  style: AppTextStyles.title3.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              Pressable(
                onTap: onCreate,
                scale: 0.94,
                pressedColor: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(100),
                padding: EdgeInsets.fromLTRB(8, 5, 10, 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 2),
                    Text(
                      '새 회의록',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: notes.isEmpty
              ? Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: EmptyCard(
                    icon: Icons.description_outlined,
                    text: '작성된 회의록이 없어요',
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: notes.length,
                  separatorBuilder: (_, _) => SizedBox(height: 4),
                  itemBuilder: (context, i) => _NoteTile(
                    note: notes[i],
                    selected: notes[i] == selected,
                    onTap: () => onSelect(notes[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _NoteTile extends StatefulWidget {
  _NoteTile({required this.note, required this.selected, required this.onTap});

  final _Note note;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NoteTile> createState() => _NoteTileState();
}

class _NoteTileState extends State<_NoteTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // 애니메이션 없이 즉시 칠한다 (색이 서서히 빠지면 두 칸이 같이 켜진 듯 보인다)
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primaryLight
                : (_hover ? AppColors.gray50 : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                note.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _date(note.date),
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  Spacer(),
                  AvatarStack(names: note.members, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  _EmptyNote({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gray200, width: 2),
            ),
            child: Center(
              child: Icon(
                Icons.description_outlined,
                size: 38,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text('회의록', style: AppTextStyles.title2),
          SizedBox(height: 6),
          Text(
            '회의 내용을 마크다운으로 적어보세요',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          SizedBox(height: 24),
          Pressable(
            onTap: onCreate,
            scale: 0.97,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '새 회의록',
                style: AppTextStyles.body2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 우측 본문 ──

class _NoteView extends StatefulWidget {
  _NoteView({
    super.key,
    required this.note,
    required this.editing,
    required this.onChanged,
    required this.onDelete,
    this.phone = false,
  });

  final _Note note;

  /// 새로 만든 회의록이면 편집 상태로 시작한다
  final bool editing;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  /// 폰은 폭이 좁아 편집 버튼을 제목 위로 올린다
  final bool phone;

  @override
  State<_NoteView> createState() => _NoteViewState();
}

class _NoteViewState extends State<_NoteView> {
  late final _title = TextEditingController(text: widget.note.title);
  final _titleFocus = FocusNode();

  late bool _editing = widget.editing;

  /// 마크다운 문법 도움말 펼침 상태
  bool _help = false;

  @override
  void initState() {
    super.initState();
    if (_editing) _titleFocus.requestFocus();
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  /// 편집 중 입력은 바로 모델에 반영한다 (목록 미리보기도 같이 갱신)
  void _sync() {
    widget.note
      ..title = _title.text.trim()
      ..updated = DateTime.now();
    widget.onChanged();
  }

  void _toggleEdit() {
    if (_editing) _sync();
    setState(() => _editing = !_editing);
  }

  Future<void> _pickDate() async {
    final note = widget.note;
    final picked = await showDatePicker(
      context: context,
      initialDate: note.date,
      firstDate: DateTime(note.date.year - 2),
      lastDate: DateTime(note.date.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              (AppColors.isDark
                      ? ColorScheme.dark(surface: AppColors.surface)
                      : ColorScheme.light(surface: AppColors.surface))
                  .copyWith(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    onSurface: AppColors.textPrimary,
                  ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => note.date = picked);
    widget.onChanged();
  }

  /// 본문의 체크박스를 눌렀을 때 그 줄만 바꿔 쓴다
  void _toggleCheckbox(int line, bool checked) {
    final lines = widget.note.body.split('\n');
    if (line >= lines.length) return;
    lines[line] = checked
        ? lines[line].replaceFirst(RegExp(r'\[[ xX]\]'), '[x]')
        : lines[line].replaceFirst(RegExp(r'\[[ xX]\]'), '[ ]');
    widget.note.body = lines.join('\n');
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final phone = widget.phone;

    final title = _editing
        ? TextField(
            controller: _title,
            focusNode: _titleFocus,
            style: AppTextStyles.title1,
            cursorColor: AppColors.primary,
            onChanged: (_) => _sync(),
            decoration: InputDecoration(
              hintText: '제목 없는 회의록',
              hintStyle: AppTextStyles.title1.copyWith(
                color: AppColors.gray300,
              ),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          )
        : Text(note.displayTitle, style: AppTextStyles.title1);

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_editing) ...[
          Pressable(
            onTap: widget.onDelete,
            scale: 0.95,
            pressedColor: AppColors.gray100,
            borderRadius: BorderRadius.circular(10),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              '삭제',
              style: AppTextStyles.body2.copyWith(
                fontSize: 14,
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 6),
        ],
        Pressable(
          onTap: _toggleEdit,
          scale: 0.95,
          child: Container(
            padding: EdgeInsets.fromLTRB(12, 8, 14, 8),
            decoration: BoxDecoration(
              color: _editing ? AppColors.primary : AppColors.gray50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _editing ? Icons.check_rounded : Icons.edit_rounded,
                  size: 15,
                  color: _editing ? Colors.white : AppColors.textSecondary,
                ),
                SizedBox(width: 4),
                Text(
                  _editing ? '완료' : '편집',
                  style: AppTextStyles.body2.copyWith(
                    fontSize: 14,
                    color: _editing ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return ListView(
      padding: phone
          // 폰 본문은 하단바 위로 올라오는 화면이라 화면 아래 여백만 남긴다
          ? EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.paddingOf(context).bottom + 32,
            )
          : EdgeInsets.fromLTRB(32, 64, 32, bottomBarInset(context)),
      children: [
        // 폰은 제목이 길어 버튼과 나란히 두면 눌린다 — 버튼을 위로 올린다
        if (phone) ...[
          Align(alignment: Alignment.centerRight, child: actions),
          SizedBox(height: 8),
          title,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              SizedBox(width: 16),
              actions,
            ],
          ),
        SizedBox(height: 10),
        // 날짜·참석자 — 편집 중에는 바로 고칠 수 있다
        if (_editing) ...[
          Row(
            children: [
              Pressable(
                onTap: _pickDate,
                scale: 0.97,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      _date(note.date),
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              // 달력 옆 마크다운 문법 도움말 (펼침)
              Pressable(
                onTap: () => setState(() => _help = !_help),
                scale: 0.97,
                pressedColor: AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '마크다운 문법',
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      _help
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_help) ...[SizedBox(height: 10), MarkdownHelpPanel()],
          SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final staff in staffList)
                _PersonChip(
                  staff: staff,
                  joined: note.members.contains(staff.name),
                  onTap: () {
                    setState(() {
                      if (note.members.contains(staff.name)) {
                        note.members.remove(staff.name);
                      } else {
                        note.members.add(staff.name);
                      }
                    });
                    widget.onChanged();
                  },
                ),
            ],
          ),
        ] else
          Row(
            children: [
              Text(
                '${_date(note.date)} (${_weekday(note.date)}) · 참석 ${note.members.length}명',
                style: AppTextStyles.caption,
              ),
              SizedBox(width: 10),
              AvatarStack(names: note.members, size: 24),
            ],
          ),
        SizedBox(height: 14),
        Container(height: 1, color: AppColors.gray100),
        SizedBox(height: 14),
        if (_editing)
          BlockEditor(
            source: widget.note.body,
            onChanged: (markdown) {
              widget.note
                ..body = markdown
                ..updated = DateTime.now();
              widget.onChanged();
            },
          )
        else if (note.body.trim().isEmpty)
          Text(
            '아직 내용이 없어요. 편집을 눌러 적어보세요',
            style: AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
          )
        else
          MarkdownView(source: note.body, onCheckbox: _toggleCheckbox),
      ],
    );
  }
}

class _PersonChip extends StatelessWidget {
  _PersonChip({required this.staff, required this.joined, required this.onTap});

  final Staff staff;
  final bool joined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: joined ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(name: staff.name, size: 22),
            SizedBox(width: 6),
            Text(
              staff.name == me ? '나' : staff.name,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: joined ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 데이터 (목업) ──

/// 회의록 한 건 — 본문은 마크다운 원문 그대로 담는다
class _Note {
  _Note({
    required this.title,
    required this.date,
    required this.members,
    required this.body,
    required this.updated,
  });

  String title;
  DateTime date;
  List<String> members;
  String body;
  DateTime updated;

  String get displayTitle => title.isEmpty ? '제목 없는 회의록' : title;

  /// 목록에 보여줄 첫 줄 (마크다운 기호는 떼고)
  String get preview {
    for (final line in body.split('\n')) {
      final text = line
          .replaceAll(RegExp(r'^(#{1,3} |[-*] \[[ xX]\] |[-*] |> |\d+\. )'), '')
          .replaceAll(RegExp(r'[*`~]'), '')
          .trim();
      if (text.isNotEmpty) return text;
    }
    return '내용 없음';
  }
}

/// 작성된 회의록 (목업). 탭을 오가도 유지되도록 모듈 전역으로 둔다.
final _notes = <_Note>[..._seed()];

List<_Note> _seed() {
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

  return [
    _Note(
      title: '주간 운영 회의',
      date: day(0),
      members: [me, '민중기', '이준승', '전상현'],
      updated: now,
      body: '''
## 안건
1. 지난주 매출 리뷰
2. 여름 이벤트 진행 상황
3. 기구 교체 일정

## 논의 내용
- 지난주 신규 등록 **18건**, 전주 대비 3건 증가
- 재등록률은 62%로 목표(65%)에 조금 못 미침
- 여름 이벤트 포스터 시안 확정, 인스타 예약 발행만 남음
> 경품은 단가를 낮추더라도 수량을 늘리는 쪽이 반응이 좋다는 의견

## 결정 사항
- 이벤트 경품은 **소형 3종 + 대형 1종**으로 확정
- 재등록 상담은 만료 2주 전부터 시작

## 할 일
- [x] 포스터 시안 확정
- [ ] 인스타 예약 발행
- [ ] 만료 예정 회원 명단 정리
- [ ] 기구 교체 견적 재확인
''',
    ),
    _Note(
      title: '여름 이벤트 킥오프',
      date: day(-3),
      members: [me, '민중기', '박준현'],
      updated: day(-3),
      body: '''
## 목표
7~8월 신규 회원 **50명** 유치

## 역할 분담
- 포스터·SNS: 전상현
- 경품 발주: 박준현
- 현장 안내: 김은후

## 일정
| 준비 기간은 2주로 잡고, 마감은 이벤트 시작 3일 전까지

- [x] 컨셉 확정
- [x] 예산 승인
- [ ] 현수막 설치
''',
    ),
    _Note(
      title: '신규 트레이너 교육 정리',
      date: day(-8),
      members: [me, '유찬빈'],
      updated: day(-8),
      body: '''
## 교육 과정
1. 센터 규정과 근무 수칙
2. 회원 응대 기본
3. 기구 사용법과 안전 수칙

## 참고
- 교육 자료는 문서함 `트레이너 온보딩` 폴더에 정리
- 첫 주는 선임 트레이너가 동행

## 피드백
- 실습 시간이 부족하다는 의견 → 다음 기수부터 실습 비중 확대
''',
    ),
  ];
}

// ── 표시용 계산 ──

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

String _weekday(DateTime time) => _weekdays[time.weekday % 7];

/// '7.30' 형태
String _date(DateTime time) => '${time.month}.${time.day}';
