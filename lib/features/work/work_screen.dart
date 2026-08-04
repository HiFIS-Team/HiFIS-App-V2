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
    // 안 주면 전 지점 기록이 다 온다
    final branchId = currentUser?.branchId;
    try {
      // 오늘 것만 받는다 — 서버가 한국 시간으로 잘라 준다
      final logs = await EnvApi.logs(
        branchId: branchId,
        date: dateKey(DateTime.now()),
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _envLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _envLoading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  List<EnvTaskLog> get _myLogs => [
    for (final log in _logs)
      if (log.employeeId == currentUser?.id) log,
  ];

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

  Widget get _myHistoryCard => _HistoryCard(
    title: '내 내역',
    logs: _myLogs,
    showName: false,
    emptyText: '오늘 완료한 항목이 없어요',
    onOpenAll: () => _showHistory(all: false, tabs: false),
  );

  Widget get _allHistoryCard => _HistoryCard(
    title: '전체 내역',
    logs: _logs,
    showName: true,
    emptyText: '오늘 완료된 항목이 없어요',
    onOpenAll: () => _showHistory(all: true, tabs: false),
  );

  /// 고른 항목의 내용 — 탭 전환 시 페이드로 바뀐다.
  /// 체크리스트 탭(환경정비)은 점수 카드 없이 내역만 보여준다.
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
          if (item.checklist)
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
                  // 내 내역 / 전체 내역만 — 데스크톱은 나란히, 폰은 위아래로
                  : isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _myHistoryCard),
                        SizedBox(width: 16),
                        Expanded(child: _allHistoryCard),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _myHistoryCard,
                        SizedBox(height: 16),
                        _allHistoryCard,
                      ],
                    ),
            )
          else if (item.label == '동료 평가')
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
