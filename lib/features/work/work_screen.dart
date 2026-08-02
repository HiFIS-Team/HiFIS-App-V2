import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/env_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/util/sf_symbols.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/desktop_header.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/see_all_button.dart';
import 'contribution_section.dart';
import 'lesson_section.dart';
import 'peer_review_section.dart';
import 'praise_section.dart';

/// 목록에 없는 일을 직접 적어 남기는 항목
///
/// 그냥 '기타' 로만 쌓이면 나중에 무슨 일을 했는지 알 길이 없다.
/// 적은 내용을 서버가 `기타(창고 정리)` 로 라벨에 접어 넣고,
/// 점수 원장·랭킹 사유까지 같은 값으로 남긴다.
const _writeInItemName = '기타';

/// 적을 수 있는 글자 수 — 넘기면 서버가 422 를 준다
/// (기록의 `itemName` 이 100자라 라벨이 넘치지 않게 막아 둔 것)
const _writeInMaxLength = 80;

/// 업무 탭 화면
///
/// 5개 평가 항목을 밑줄 탭으로 전환하며 항목별 점수와 상세를 보여준다.
/// 환경정비는 서버 데이터로 돌고, 나머지 항목은 아직 목업이다.
class WorkScreen extends StatefulWidget {
  WorkScreen({super.key});

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> {
  int _tab = 0;

  /// 환경정비 항목과 배점 — 지점마다 다르다
  List<EnvItem> _envItems = const [];

  /// 오늘 지점에서 나온 수행 기록 전부 (내 것 + 동료 것)
  List<EnvTaskLog> _logs = const [];

  bool _envLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEnv();
  }

  Future<void> _loadEnv() async {
    // 지점을 반드시 지정한다 — 대표·관리자는 지점 스코프가 안 걸려서
    // 안 주면 전 지점 항목이 다 온다 (지점 3개면 항목이 3벌씩 나온다)
    final branchId = currentUser?.branchId;
    try {
      final itemRequest = EnvApi.items(branchId: branchId);
      // 화면이 "오늘 점검"이라 오늘 것만 받는다 — 서버가 한국 시간으로 잘라 준다
      final logRequest = EnvApi.logs(
        branchId: branchId,
        date: dateKey(DateTime.now()),
      );
      final items = await itemRequest;
      final logs = await logRequest;
      if (!mounted) return;
      setState(() {
        _envItems = _sortForDisplay(items);
        _logs = logs;
        _envLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _envLoading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 화면에 세우는 순서 — 하루 일하는 흐름대로
  ///
  /// 서버는 배점이 높은 순으로 준다. 그러면 매일 여러 번 누르는 세탁(1점)이
  /// 맨 아래로 가고 어쩌다 하는 현수막(10점)이 맨 위에 온다.
  /// 빨래·청소 → 관리 → 홍보 → 기타 순으로 다시 세운다.
  static const _envOrder = [
    '세탁',
    '건조기',
    '빨래정리',
    '구역청소',
    '복도청소',
    '락커정리',
    '남탈부스',
    '남탈청소',
    '여탈부스',
    '여탈청소',
    '화장실청소',
    '기구관리',
    '회원지도',
    'TM회원관리',
    '게시물',
    '스토리',
    '전단지',
    '현수막',
    '족자',
    '블로그',
    '클레임해결',
    '기타',
  ];

  /// 이름 비교용 열쇠 — 공백·대소문자를 지우고 맞춘다
  ///
  /// 지금은 서버 이름과 위 목록이 딱 맞지만, '기타'는 지점이 이름을 고칠 수
  /// 있어서 띄어쓰기 하나로 순서에서 빠지지 않게 해 둔다.
  static String _envKey(String name) => name.replaceAll(' ', '').toLowerCase();

  static List<EnvItem> _sortForDisplay(List<EnvItem> items) {
    final rank = {
      for (var i = 0; i < _envOrder.length; i++) _envKey(_envOrder[i]): i,
    };
    return [...items]..sort((a, b) {
      // 목록에 없는 항목(지점이 새로 만든 것)은 맨 뒤에 이름순으로 붙인다
      final ra = rank[_envKey(a.name)] ?? _envOrder.length;
      final rb = rank[_envKey(b.name)] ?? _envOrder.length;
      return ra != rb ? ra.compareTo(rb) : a.name.compareTo(b.name);
    });
  }

  List<EnvTaskLog> get _myLogs => [
    for (final log in _logs)
      if (log.employeeId == currentUser?.id) log,
  ];

  /// 항목 id 별 오늘 내 수행 횟수
  Map<String, int> get _counts {
    final counts = <String, int>{};
    for (final log in _myLogs) {
      counts[log.envItemId] = (counts[log.envItemId] ?? 0) + 1;
    }
    return counts;
  }

  /// 목록에 없는 걸 적어 남기는 항목인가 ('기타')
  static bool _isWriteIn(EnvItem item) =>
      _envKey(item.name) == _envKey(_writeInItemName);

  Future<void> _adjust(EnvItem item, int delta) async {
    try {
      if (delta > 0) {
        // '기타'는 무슨 일을 했는지 먼저 받는다 — 안 적으면 남길 이유가 없다
        String? note;
        if (_isWriteIn(item)) {
          note = await showAppDialog<String>(
            context,
            (_) => _WriteInCard(item: item),
          );
          if (note == null || !mounted) return;
        }
        final log = await EnvApi.createLog(item.id, note: note);
        if (!mounted) return;
        setState(() => _logs = [log, ..._logs]);
        AppToast.show(
          context,
          note == null
              ? '${_withJosa(item.name)} 완료했습니다 · +${item.points}점'
              : '"$note" 기록했습니다 · +${item.points}점',
        );
      } else {
        // 감소는 그 항목의 내 기록 중 가장 최근 것을 지운다 (점수도 같이 회수된다)
        EnvTaskLog? target;
        for (final log in _myLogs) {
          if (log.envItemId != item.id) continue;
          if (target == null || log.createdAt.isAfter(target.createdAt)) {
            target = log;
          }
        }
        if (target == null) return;
        await EnvApi.deleteLog(target.id);
        if (!mounted) return;
        setState(() {
          _logs = [
            for (final log in _logs)
              if (log.id != target!.id) log,
          ];
        });
      }
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 오늘 수행 내역 — 폰은 밀려 들어오는 화면, PC는 모달로 열린다
  ///
  /// [tabs]를 끄면 [all]로 지정한 쪽만 보여준다 (데스크톱 카드에서 열 때).
  void _showHistory({bool all = false, bool tabs = true}) {
    showFullPage<void>(
      context,
      (_) => _HistoryScreen(
        myLogs: _myLogs,
        allLogs: List.of(_logs),
        initialAll: all,
        tabs: tabs,
      ),
    );
  }

  /// 받침 유무에 따라 을/를을 붙인다 (한글이 아니면 을(를))
  String _withJosa(String word) {
    final code = word.codeUnits.last;
    if (code < 0xAC00 || code > 0xD7A3) return '$word을(를)';
    return (code - 0xAC00) % 28 != 0 ? '$word을' : '$word를';
  }

  /// 항목 목록 — 환경정비의 점검 항목은 서버(지점별)에서 받아 온다
  static const _items = [
    _WorkItem(label: '환경정비', checklist: true),
    _WorkItem(label: '동료 평가'),
    _WorkItem(label: '회원 친절도'),
    _WorkItem(label: '수업 개수'),
    _WorkItem(label: '센터 기여도'),
  ];

  /// 항목 탭 — 데스크톱은 알약 토글, 폰은 밑줄 스타일
  Widget _tabs() {
    // 데스크톱은 넓은 화면에 밑줄 탭이 헐거워 보여서
    // 분절 토글(ModeSwitch) 스타일의 알약 탭으로 보여준다
    if (isDesktop) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _WorkSegmentedTabs(
          labels: [for (final item in _items) item.label],
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
      );
    }

    // 항목 탭 — 사내톡 상세 '공유된 콘텐츠' 탭과 같은 밑줄 스타일.
    // 5개가 한 화면에 다 들어와야 하므로 칸을 균등하게 나누고,
    // 좁은 화면에서는 글자를 살짝 줄여서라도 옆으로 밀리지 않게 한다.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              // 밑줄은 칸 전체가 아니라 글자 폭에 맞춘다
              child: Center(
                child: _WorkTab(
                  label: _items[i].label,
                  selected: _tab == i,
                  onTap: () => setState(() => _tab = i),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_tab];

    // 안드로이드는 글래스가 없어서 항목 탭이 같이 올라가 봐야 얻는 게 없다.
    // 목록 화면들처럼 탭을 고정하고 내용만 스크롤한다.
    if (!isApple && !isDesktop) {
      return Scaffold(
        body: Column(
          children: [
            ColoredBox(
              color: AppColors.background,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: _tabs(),
                ),
              ),
            ),
            Container(height: 1, color: AppColors.gray100),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(0, 20, 0, bottomBarInset(context)),
                children: [_content(item)],
              ),
            ),
          ],
        ),
      );
    }

    // 데스크톱은 다른 PC 화면(직원·근태·급여·랭킹)과 머리 모양을 맞춘다.
    // 타이틀 없이 탭부터 시작하면 이 화면만 위가 비어 보인다.
    if (isDesktop) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(24, 64, 24, 32),
            children: [
              DesktopHeader(title: '업무', subtitle: '이번 달 평가 항목을 확인하고 기록해요'),
              SizedBox(height: 22),
              _tabs(),
              SizedBox(height: 16),
              _content(item),
            ],
          ),
        ),
      );
    }

    // 홈처럼 화면 전체가 한 번에 스크롤된다.
    // 항목 탭도 같이 올라가야 위쪽 글래스 버튼에 콘텐츠가 비친다.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, 64, 0, bottomBarInset(context)),
          children: [
            _tabs(),
            Container(height: 1, color: AppColors.gray100),
            SizedBox(height: 20),
            _content(item),
          ],
        ),
      ),
    );
  }

  /// 콘텐츠 좌우 여백 — 데스크톱은 페이지 ListView가 이미 24를 준다
  double get _pad => isDesktop ? 0 : 20;

  /// 고른 항목의 내용 — 탭 전환 시 페이드로 바뀐다.
  /// 체크리스트 탭(환경정비)은 점수 카드 없이 리스트만 보여준다.
  Widget _content(_WorkItem item) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 200),
      // 기본 정렬(가운데)은 높이가 다른 콘텐츠가 아래로 밀렸다
      // 올라와 보이므로 위쪽 기준으로 겹친다
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, ?currentChild],
      ),
      child: Column(
        key: ValueKey(_tab),
        children: [
          if (item.checklist) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _pad),
              child: _envLoading
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    )
                  : _ChecklistCard(
                      items: _envItems,
                      counts: _counts,
                      onAdjust: _adjust,
                      onShowHistory: _showHistory,
                    ),
            ),
            // 데스크톱: 내 내역 / 전체 내역을 양쪽에 상시 표시
            if (isDesktop) ...[
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _pad),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _HistoryCard(
                        title: '내 내역',
                        logs: _myLogs,
                        showName: false,
                        emptyText: '오늘 완료한 항목이 없어요',
                        onOpenAll: () => _showHistory(all: false, tabs: false),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _HistoryCard(
                        title: '전체 내역',
                        logs: _logs,
                        showName: true,
                        emptyText: '오늘 완료된 항목이 없어요',
                        onOpenAll: () => _showHistory(all: true, tabs: false),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (item.label == '동료 평가')
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _pad),
              child: PeerReviewSection(),
            )
          else if (item.label == '수업 개수')
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _pad),
              child: LessonSection(),
            )
          else if (item.label == '회원 친절도')
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _pad),
              child: PraiseSection(),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _pad),
              child: ContributionSection(),
            ),
        ],
      ),
    );
  }
}

/// '기타'에 적을 내용을 받는 팝업
///
/// 비워 두면 완료할 수 없다. 적은 내용이 그대로 기록에 남는 자리라
/// 빈 '기타' 는 남겨 봐야 나중에 아무 의미가 없다.
class _WriteInCard extends StatefulWidget {
  _WriteInCard({required this.item});

  final EnvItem item;

  @override
  State<_WriteInCard> createState() => _WriteInCardState();
}

class _WriteInCardState extends State<_WriteInCard> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 글자 수와 완료 버튼 상태가 입력 따라 바뀐다
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _value => _text.text.trim();

  void _submit() {
    if (_value.isEmpty) return;
    Navigator.pop(context, _value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dialogWidth(context, 320),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('무엇을 했나요?', style: AppTextStyles.title3),
          SizedBox(height: 6),
          Text(
            '목록에 없는 일을 적어주세요. 적은 내용이 기록에 그대로 남아요.',
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
          SizedBox(height: 14),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _text,
              autofocus: true,
              maxLength: _writeInMaxLength,
              style: AppTextStyles.body1,
              cursorColor: AppColors.primary,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '예) 창고 정리',
                hintStyle: AppTextStyles.body1.copyWith(
                  color: AppColors.gray400,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                // 기본 글자 수 표시는 칸 밖으로 삐져나온다 — 아래에 직접 둔다
                counterText: '',
              ),
            ),
          ),
          SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_text.text.characters.length} / $_writeInMaxLength',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: AppColors.gray400,
              ),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '취소',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: '완료',
                  filled: _value.isNotEmpty,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 수행 기록을 누가 남겼는지 — 서버는 직원 id 만 준다
String _logAuthor(EnvTaskLog log) =>
    StaffDirectory.instance.byId(log.employeeId)?.name ?? '알 수 없음';

/// 업무 탭의 항목 하나 — 내용은 항목마다 전용 섹션 위젯이 그린다
class _WorkItem {
  const _WorkItem({required this.label, this.checklist = false});

  final String label;

  /// 2열 점검 체크리스트를 쓰는 항목인지 (환경정비만)
  final bool checklist;
}

/// 데스크톱 업무 항목 탭 — 회색 트랙 위에 흰 알약이 움직이는 분절 토글.
/// 커서를 올리면 선택되지 않은 칸도 옅게 반응한다.
class _WorkSegmentedTabs extends StatefulWidget {
  _WorkSegmentedTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  State<_WorkSegmentedTabs> createState() => _WorkSegmentedTabsState();
}

class _WorkSegmentedTabsState extends State<_WorkSegmentedTabs> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: EdgeInsets.all(4),
      decoration: segmentTrack(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < widget.labels.length; i++) _segment(i)],
      ),
    );
  }

  Widget _segment(int index) {
    final selected = index == widget.selected;
    final hovered = index == _hover;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = index),
      onExit: (_) => setState(() {
        if (_hover == index) _hover = null;
      }),
      child: Pressable(
        scale: 0.97,
        borderRadius: BorderRadius.circular(10),
        onTap: () => widget.onSelect(index),
        // 배경은 애니메이션 없이 즉시 — 페이드가 있으면 직전에 선택돼 있던
        // 칸의 알약이 서서히 사라지며 둘 다 눌린 것처럼 보인다
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: segmentFill(selected: selected, hovered: hovered),
          child: Text(
            widget.labels[index],
            maxLines: 1,
            style: AppTextStyles.body2.copyWith(
              fontSize: 14,
              color: selected ? AppColors.primary : AppColors.gray600,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkTab extends StatelessWidget {
  _WorkTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// true면 주어진 칸을 채우고 가운데 정렬 (내역 화면처럼 Expanded로 쓸 때)
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      style: AppTextStyles.body2.copyWith(
        fontSize: 14,
        color: selected ? AppColors.textPrimary : AppColors.gray500,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );

    // 칸이 좁으면 글자를 줄여서 맞춘다 (옆으로 밀리거나 잘리지 않게)
    final fitted = FittedBox(fit: BoxFit.scaleDown, child: text);

    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Container(
        // 밑줄이 글자보다 살짝 넓게 깔리도록 좌우 여유를 준다
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: expand ? Center(child: fitted) : fitted,
      ),
    );
  }
}

/// 환경정비 점검 카드 — 항목이 2열로 내려가며 배치되고,
/// 각 항목의 좌우 −/+ 버튼으로 오늘 수행 횟수를 조절한다.
class _ChecklistCard extends StatelessWidget {
  _ChecklistCard({
    required this.items,
    required this.counts,
    required this.onAdjust,
    required this.onShowHistory,
  });

  final List<EnvItem> items;

  /// 항목 id 별 오늘 수행 횟수
  final Map<String, int> counts;

  /// (항목, 증감량) — +1 또는 -1
  final void Function(EnvItem item, int delta) onAdjust;

  /// 오늘 내역 시트 열기 (폰 전용)
  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (sum, c) => sum + c);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(child: Text('오늘 점검 항목', style: AppTextStyles.label)),
                // 데스크톱은 아래에 내역 카드가 있어 총 횟수만 적고,
                // 폰은 누르면 오늘 수행 내역이 열린다
                if (isDesktop)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '총 $total회',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  SeeAllButton(onTap: onShowHistory, label: '총 $total회'),
              ],
            ),
          ),
          SizedBox(height: 14),
          // 데스크톱은 폭이 넓어 한 줄에 여러 개를 넣는다.
          // 칩이 찌그러지지 않게 남는 폭에 맞춰 개수를 정한다(최대 4개).
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = isDesktop
                  ? (constraints.maxWidth / 220).floor().clamp(2, 4)
                  : 2;
              // 칩마다 글자를 알아서 줄이면 긴 라벨('화장실청소')만 작아 보인다.
              // 제일 긴 라벨이 들어가는 크기를 구해 모든 칩이 같이 쓴다 —
              // 폰은 칸이 좁아 애플·안드로이드 모두 필요하다.
              final chipWidth =
                  (constraints.maxWidth - 10 * (columns - 1)) / columns;
              final fontSize = _chipFontSize([
                for (final item in items) item.name,
              ], chipWidth);
              return Column(
                children: [
                  for (var i = 0; i < items.length; i += columns) ...[
                    if (i > 0) SizedBox(height: 10),
                    Row(
                      children: [
                        for (var col = 0; col < columns; col++) ...[
                          if (col > 0) SizedBox(width: 10),
                          Expanded(
                            child: i + col < items.length
                                ? _CountChip(
                                    label: items[i + col].name,
                                    count: counts[items[i + col].id] ?? 0,
                                    fontSize: fontSize,
                                    onAdjust: (delta) =>
                                        onAdjust(items[i + col], delta),
                                  )
                                : SizedBox(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 좌 − / 우 + 버튼이 달린 횟수 칩
/// 칩 안에서 글자가 쓸 수 있는 폭에 맞춰, 모든 라벨이 함께 쓸 글자 크기를 구한다.
///
/// 제일 긴 라벨이 들어가는 크기를 찾아 전부에 같은 값을 준다.
/// 굵은 글씨(수행한 칩)를 기준으로 재서, 눌렀을 때 글자 크기가 흔들리지 않는다.
double _chipFontSize(List<String> items, double chipWidth) {
  const base = 14.0;
  final available = chipWidth - _CountChip.buttonWidth * 2 - 6;
  if (available <= 0) return base;

  var size = base;
  for (final label in items) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: AppTextStyles.body2.copyWith(
          fontSize: base,
          fontWeight: FontWeight.w700,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    if (painter.width > available) {
      final fit = base * available / painter.width;
      if (fit < size) size = fit;
    }
  }
  return size.clamp(10.0, base);
}

class _CountChip extends StatelessWidget {
  _CountChip({
    required this.label,
    required this.count,
    required this.onAdjust,
    required this.fontSize,
  });

  final String label;
  final int count;
  final ValueChanged<int> onAdjust;

  /// 모든 칩이 함께 쓰는 글자 크기 — 길이와 상관없이 같아 보이게 한다
  final double fontSize;

  /// 좌우 −/+ 버튼 한 개의 폭
  static const double buttonWidth = 42;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;

    return AnimatedContainer(
      duration: Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 48,
      decoration: BoxDecoration(
        color: active ? AppColors.primaryLight : AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
        // 활성 칩에만 은은한 파란 테두리
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: 0.25)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          _AdjustButton(
            // 감소는 빨강, 횟수가 없으면 비활성 회색
            icon: CupertinoIcons.minus,
            color: active ? AppColors.error : AppColors.gray300,
            onTap: () => onAdjust(-1),
          ),
          // 글자 크기는 [_chipFontSize]가 모든 칩에 같은 값을 주므로
          // 여기서 줄어들 일은 없다. 계산이 한 픽셀 모자랄 때를 대비한
          // 안전망으로만 둔다 — 잘라내는(…) 것보다는 줄이는 게 낫다.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppTextStyles.body2.copyWith(
                  fontSize: fontSize,
                  color: active ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
          _AdjustButton(
            icon: CupertinoIcons.plus,
            color: AppColors.primary,
            onTap: () => onAdjust(1),
          ),
        ],
      ),
    );
  }
}

/// 스테퍼 버튼 — 누르는 동안 원이 줄어들며 버튼 색으로 물든다
class _AdjustButton extends StatefulWidget {
  _AdjustButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_AdjustButton> createState() => _AdjustButtonState();
}

class _AdjustButtonState extends State<_AdjustButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: SizedBox(
        width: _CountChip.buttonWidth,
        height: 48,
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? 0.82 : 1.0,
            duration: Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 110),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _pressed
                    ? widget.color.withValues(alpha: 0.18)
                    : AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 13, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}

/// 수행 기록 한 줄 — 시각 · (이름) · 항목 · 완료 체크.
/// 내역 화면과 데스크톱 인라인 내역 카드가 함께 쓴다.
class _LogRow extends StatelessWidget {
  _LogRow({required this.log, required this.showName});

  final EnvTaskLog log;

  /// 전체 내역처럼 누가 했는지 함께 보여줄지
  final bool showName;

  static String formatTime(DateTime time) {
    final period = time.hour < 12 ? '오전' : '오후';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$period $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              formatTime(log.createdAt),
              style: AppTextStyles.caption,
            ),
          ),
          SizedBox(width: 8),
          if (showName) ...[
            Text(
              _logAuthor(log),
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                log.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ] else
            Expanded(
              child: Text(
                log.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // 그때 받은 점수 — 항목 배점이 나중에 바뀌어도 이 값은 안 바뀐다
          Text(
            '+${log.points}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 6),
          Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 16,
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

/// 데스크톱에서 점검 항목 아래에 상시 떠 있는 내역 카드.
/// 다섯 줄까지만 펼치고 그보다 많으면 카드 안에서 스크롤한다.
class _HistoryCard extends StatefulWidget {
  _HistoryCard({
    required this.title,
    required this.logs,
    required this.showName,
    required this.emptyText,
    required this.onOpenAll,
  });

  final String title;
  final List<EnvTaskLog> logs;
  final bool showName;
  final String emptyText;

  /// 카드에는 다섯 줄만 보이므로 나머지는 모달에서 본다
  final VoidCallback onOpenAll;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  final _scrollController = ScrollController();

  /// 한 줄 높이(위아래 여백 13 + 본문 22.5)에 구분선을 더한 다섯 줄 높이.
  /// 기록이 적어도 이 높이를 유지해 좌우 카드가 같은 크기로 보인다.
  static const _listHeight = 5 * 48.5 + 4;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List.of(widget.logs)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(widget.title, style: AppTextStyles.label),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '총 ${sorted.length}회',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SeeAllButton(onTap: widget.onOpenAll),
              ],
            ),
          ),
          // 기록 수가 달라도 좌우 카드 높이가 어긋나지 않게 높이를 고정한다
          SizedBox(
            height: _listHeight,
            child: sorted.isEmpty
                ? Padding(
                    padding: EdgeInsets.fromLTRB(4, 20, 4, 20),
                    child: Text(
                      widget.emptyText,
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                : Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        children: [
                          for (var i = 0; i < sorted.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: AppColors.divider),
                            _LogRow(log: sorted[i], showName: widget.showName),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 오늘 수행 내역 화면 — 옆에서 슬라이드되어 열린다
///
/// 폰은 들어오는 문이 하나뿐이라 내 내역/전체 내역 탭으로 오간다.
/// 데스크톱은 두 카드가 각각 '전체 보기'를 갖고 있어서, 누른 쪽만
/// 열어 준다 ([tabs]가 false) — 눌렀는데 다른 것까지 나오면 헷갈린다.
class _HistoryScreen extends StatefulWidget {
  _HistoryScreen({
    required this.myLogs,
    required this.allLogs,
    this.initialAll = false,
    this.tabs = true,
  });

  final List<EnvTaskLog> myLogs;
  final List<EnvTaskLog> allLogs;

  /// 어느 쪽으로 열지 (데스크톱은 누른 카드에 맞춰 연다)
  final bool initialAll;

  /// 내 내역·전체 내역 전환 탭을 보여줄지
  final bool tabs;

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> {
  /// true면 전체 내역
  late bool _all = widget.initialAll;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = '${now.month}월 ${now.day}일 ${_weekdays[now.weekday - 1]}요일';
    final logs = _all ? widget.allLogs : widget.myLogs;
    final sorted = List.of(logs)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 고정 타이틀 영역만큼 비워둔다
                SizedBox(height: 56),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: [
                      Expanded(child: Text(date, style: AppTextStyles.caption)),
                      Text(
                        '총 ${logs.length}회',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: widget.tabs ? 8 : 14),
                // 내 내역 / 전체 내역 전환 탭 (업무 탭과 같은 밑줄 스타일)
                if (widget.tabs)
                  Row(
                    children: [
                      Expanded(
                        child: _WorkTab(
                          label: '내 내역',
                          selected: !_all,
                          expand: true,
                          onTap: () => setState(() => _all = false),
                        ),
                      ),
                      Expanded(
                        child: _WorkTab(
                          label: '전체 내역',
                          selected: _all,
                          expand: true,
                          onTap: () => setState(() => _all = true),
                        ),
                      ),
                    ],
                  ),
                Container(height: 1, color: AppColors.gray100),
                if (sorted.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                    child: Text(
                      _all ? '오늘 완료된 항목이 없어요' : '오늘 완료한 항목이 없어요',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      key: ValueKey(_all),
                      padding: EdgeInsets.fromLTRB(
                        24,
                        12,
                        24,
                        MediaQuery.paddingOf(context).bottom + 24,
                      ),
                      itemCount: sorted.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: AppColors.divider),
                      // 전체 내역에서는 누가 했는지 이름을 함께 보여준다
                      itemBuilder: (_, index) =>
                          _LogRow(log: sorted[index], showName: _all),
                    ),
                  ),
              ],
            ),
          ),
          // 상단 중앙 고정 타이틀 (터치는 아래로 통과)
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text(
                    widget.tabs
                        ? '오늘 내역'
                        : _all
                        ? '전체 내역'
                        : '내 내역',
                    style: AppTextStyles.title3,
                  ),
                ),
              ),
            ),
          ),
          // 좌측 상단 고정 뒤로가기 글래스 버튼
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
