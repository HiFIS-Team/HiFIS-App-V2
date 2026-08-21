import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/env_api.dart';
import '../../core/data/branch_scope.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/header_action.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/photo.dart';
import '../../core/util/photo_cache.dart';
import '../../core/util/platform.dart';
import '../../core/util/sf_symbols.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/util/skeleton_delay.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/glass_search_bar.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/input/see_all_button.dart';
import '../../core/widgets/nav/people_filter_button.dart';
import '../../core/widgets/nav/desktop_header.dart';
import 'contribution/contribution_section.dart';
import 'lesson/lesson_section.dart';
import 'my_task/my_task_section.dart';
import 'peer_review/peer_review_section.dart';
import 'praise/praise_section.dart';
import '../../core/widgets/nav/pane_transition.dart';
import '../../core/util/screen_refresh.dart';
part 'work_tabs.dart';
part 'work_checklist.dart';
part 'work_history.dart';

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

class _WorkScreenState extends State<WorkScreen>
    with ScreenRefresh<WorkScreen>, SkeletonDelay<WorkScreen> {
  int _tab = 0;

  /// 환경정비 안의 목록바 — 0 공통 업무 · 1 내 업무
  ///
  /// **직접 수행하는 사람에게만 뜬다** (`_canDoEnv`). 대표·관리자는 내 업무가
  /// 없어서 예전처럼 내역만 본다 (2026-08-14 — 매니저·멤버 화면부터 만든다).
  int _envTab = 0;

  /// 헤더 `+` 로 업무를 추가하면 오른다 — [MyTaskSection] 이 다시 받는다
  int _myTaskReload = 0;

  /// 화면 왼쪽 끝의 `+` 를 켜고 끈다
  ///
  /// **환경정비 탭에 있는 내내 둔다.** 공통 업무 / 내 업무 칸을 옮길 때마다
  /// 켰다 껐다 하면 버튼이 생겼다 없어져서 그게 곧 깜빡임이다.
  /// 공통 업무를 보다가 눌러도 되게, 만들고 나면 내 업무 칸으로 옮겨 준다.
  void _syncHeaderAction() => _setHeaderAction(
    _canDoEnv && _items[_tab].checklist
        ? HeaderAction(symbol: 'plus', onPressed: _addMyTask)
        : null,
  );

  /// **한 프레임 뒤에** 바꾼다
  ///
  /// 탭이 보이고 가려지는 신호(`TickerMode`)가 **빌드 도중**에 온다.
  /// 그때 값을 바꾸면 헤더가 빌드 중에 다시 빌드되라고 표시돼서
  /// `setState() called during build` 로 죽는다 (실제로 겪었다).
  void _setHeaderAction(HeaderAction? next) {
    if (headerAction.value == next) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) headerAction.value = next;
    });
  }

  Future<void> _addMyTask() async {
    if (await addMyTasks(context) && mounted) {
      setState(() {
        _myTaskReload++;
        // 만든 것을 바로 보여준다 — 공통 업무를 보다 눌렀을 수도 있다
        _envTab = 1;
      });
    }
  }

  /// 환경정비 항목과 배점 — 지점마다 다르다
  List<EnvItem> _envItems = const [];

  /// 오늘 지점에서 나온 수행 기록 전부 (내 것 + 동료 것)
  ///
  /// **이 화면은 늘 오늘이다.** 지난 날짜는 전체보기 화면(`_HistoryScreen`)에서
  /// 날짜를 옮겨 본다 — `+` 가 서버에 **누른 시각**으로 남아서 지난 날짜에는
  /// 만들 수가 없고, 그러면 칩과 내역이 서로 다른 날을 가리키게 된다.
  List<EnvTaskLog> _logs = const [];

  static DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 다섯 항목이 같이 보는 지점 — null 이면 전 지점
  ///
  /// **셸 헤더의 지점 아이콘 하나가 정한다** (조직도·랭킹·근태와 같은 값).
  /// 예전에는 폰만 이 화면 왼쪽 위에 고르개를 따로 갖고 있었는데, 화면마다
  /// 있으면 어느 것이 무엇에 걸리는지 헷갈려서 한 곳으로 모았다.
  ///
  /// 고르개는 MASTER·ADMIN 에게만 있고, 나머지는 늘 null 이다.
  /// 그 둘은 서버가 본인 지점으로 고정하므로 null 이 곧 '내 지점'이 된다.
  String? get _branch => branchScopeId;

  /// 탭에 다시 들어오거나 앱이 다시 앞으로 나왔을 때 조용히 다시 받는다
  @override
  Future<void> onScreenRefresh() => _loadEnv();

  /// 다른 탭으로 가면 헤더 `+` 를 치운다
  ///
  /// `LazyIndexedStack` 이라 탭을 옮겨도 이 화면이 안 죽는다 — `dispose` 를
  /// 기다리면 홈·프로젝트에서도 이 버튼이 떠 있게 된다.
  @override
  void onScreenVisibility(bool visible) {
    if (visible) {
      _syncHeaderAction();
    } else {
      _setHeaderAction(null);
    }
  }

  @override
  void initState() {
    super.initState();
    branchScope.addListener(_onBranchScope);
    _loadEnv();
    // 첫 화면이 환경정비라 여기서 한 번 맞춘다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncHeaderAction();
    });
  }

  @override
  void dispose() {
    branchScope.removeListener(_onBranchScope);
    // 안 비우면 다른 탭에서도 이 버튼이 남는다
    headerAction.value = null;
    super.dispose();
  }

  /// 헤더에서 지점을 바꿨다 — 이 화면이 들고 있는 것만 다시 받는다.
  /// 항목 화면들은 각자 `didUpdateWidget` 에서 다시 받는다.
  ///
  /// **칩·내역을 안 지운다.** 빨리 오면 뼈대가 아예 안 뜨고 옛 판 위에 새 값이
  /// 얹힌다 (`SkeletonDelay`) — 지점을 바꿀 때마다 깜빡이던 자리다.
  void _onBranchScope() {
    if (!mounted) return;
    setState(beginLoad);
    _loadEnv();
  }

  Future<void> _loadEnv() async {
    final branchId = _branch;
    try {
      // 점검 항목은 **직접 수행하는 사람**만 쓴다(`_canDoEnv`).
      // 대표·관리자는 그리지도 않는 데다, 전 지점을 고르면 지점 수만큼
      // 같은 항목이 겹쳐 오므로 아예 안 받는다.
      final itemRequest = _canDoEnv
          ? EnvApi.items(branchId: branchId)
          : Future.value(const <EnvItem>[]);
      // 화면이 "오늘 점검"이라 오늘 것만 받는다 — 서버가 한국 시간으로 잘라 준다
      final logRequest = EnvApi.logs(
        branchId: branchId,
        date: dateKey(_todayDate()),
      );
      final items = await itemRequest;
      final logs = await logRequest;
      if (!mounted) return;
      setState(() {
        // 서버가 sortOrder 순으로 준다 — 앱이 다시 세우지 않는다
        _envItems = items;
        _logs = logs;
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 이름 비교용 열쇠 — 공백·대소문자를 지우고 맞춘다
  ///
  /// '기타'는 지점이 이름을 고칠 수 있어서 띄어쓰기 하나로 못 알아보는 일이
  /// 없게 해 둔다.
  static String _envKey(String name) => name.replaceAll(' ', '').toLowerCase();

  /// 오늘 내 기록 — 칩의 숫자와 `−` 로 지울 대상이 여기서 나온다
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
        // 현수막은 사진과 위치를 먼저 받는다 — 창 안에서 사진까지 올리고 온다
        String? photoUrl;
        String? place;
        if (_needsPhoto(item)) {
          final proof = await showAppDialog<({String url, String place})>(
            context,
            (_) => _PhotoProofCard(item: item),
          );
          if (proof == null || !mounted) return;
          photoUrl = proof.url;
          place = proof.place;
        }
        final log = await EnvApi.createLog(
          item.id,
          note: note,
          photoUrl: photoUrl,
          place: place,
        );
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
        // 날짜를 옮기면 그 화면이 직접 다시 받는다 — 어느 지점인지 넘겨준다
        branchId: _branch,
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
      // 랭킹과 같이 **폭을 꽉 채워 균등하게** 나눈다.
      // 예전에는 글자 폭만큼만 잡고 왼쪽에 붙여 뒀는데, 넓은 화면에서
      // 오른쪽이 휑하게 남아 랭킹 탭과 결이 달랐다.
      return SegmentedTabs(
        labels: [for (final item in _items) item.label],
        selected: _tab,
        onSelect: (i) => setState(() {
          _tab = i;
          _syncHeaderAction();
        }),
      );
    }

    // 항목 탭 — 사내톡 상세 '공유된 콘텐츠' 탭과 같은 밑줄 스타일.
    // 5개가 한 화면에 다 들어와야 하므로 칸을 균등하게 나누고,
    // 좁은 화면에서는 글자를 살짝 줄여서라도 옆으로 밀리지 않게 한다.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: UnderlineTabs(
        labels: [for (final item in _items) item.label],
        selected: _tab,
        // 데스크톱 탭(`SegmentedTabs`)과 **같이** 헤더를 맞춘다.
        // 한쪽만 고쳐서 다른 항목에도 `+` 가 남았던 자리다.
        onSelect: (i) => setState(() {
          _tab = i;
          _syncHeaderAction();
        }),
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
              // 머리말의 오른쪽 끝 — 화면 전체에 걸리는 컨트롤이 서는 자리다
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

  /// 환경정비를 **직접 수행하는 사람**인가 — 점검 항목 칩이 이 사람에게만 보인다.
  ///
  /// 서버가 `POST /env-logs` 를 **MEMBER·MANAGER 에게만** 열어 둔다
  /// (ADMIN·MASTER 는 운영 전담이라 403 — 세션 싸인과 같은 기준).
  /// 대표·관리자에게 칩을 보여줘 봐야 누르면 '권한이 없습니다' 만 뜬다.
  bool get _canDoEnv => myRole == Role.member || myRole == Role.manager;

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
    // 대표·관리자는 '내 내역'이 없어서 이 카드가 혼자 선다 —
    // 옆에 맞출 카드가 없으니 두 배로 보여준다 (2026-08-14 대표 요청)
    rows: _canDoEnv ? 5 : 10,
  );

  /// 고른 항목의 내용 — 탭 전환 시 페이드로 바뀐다.
  /// 체크리스트 탭(환경정비)은 점수 카드 없이 리스트만 보여준다.
  Widget _content(_WorkItem item) {
    // 사이드바 화면 전환·모니터링 패널과 **같은 모션**을 쓴다.
    // 예전에는 여기만 자체 AnimatedSwitcher(200ms 페이드)였다.
    return PaneTransition(
      step: _tab,
      child: Column(
        children: [
          if (item.checklist)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _pad),
              child: showSkeleton
                  ? _ChecklistSkeleton()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 라벨이 권한마다 다르다 — 대표·관리자에게 `내 업무` 는
                        // 자기 것이 아니라 **직원들 것**이라 말이 안 맞는다.
                        SegmentedTabs(
                          labels: _canDoEnv
                              ? const ['공통 업무', '내 업무']
                              : const ['지점 업무', '개인 업무'],
                          selected: _envTab,
                          onSelect: (i) => setState(() => _envTab = i),
                        ),
                        SizedBox(height: 16),
                        // 칸을 옮기면 **아래에서 살짝 올라온다** — 회원 친절도·
                        // 랭킹·모니터링 목록바와 같은 움직임이다.
                        //
                        // `PaneTransition` 은 자식을 갈아끼우지 않고 감싼 채로
                        // 다시 재생한다. 그래서 아래 두 칸을 **다 살려 둔 채로**
                        // 애니메이션만 얹을 수 있다 — 옮길 때마다 새로 만들면
                        // `initState → 뼈대` 가 번쩍인다. `Offstage` 는 상태를
                        // 그대로 두고 그리지도 재지도 않으며, 덤으로 내 업무를
                        // 공통 업무를 보는 동안 미리 받아 둔다.
                        PaneTransition(
                          step: _envTab,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Offstage(
                                offstage: _envTab != 1,
                                child: _canDoEnv
                                    ? MyTaskSection(reloadToken: _myTaskReload)
                                    // 대표·관리자는 사람 목록을 본다 —
                                    // 누르면 그 사람 업무가 밀려 들어온다
                                    : MyTaskRoster(),
                              ),
                              Offstage(
                                offstage: _envTab == 1,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // 점검 항목은 **직접 수행하는 사람에게만** —
                                    // 대표·관리자는 내역만 본다 (서버가 기록을 안 받는다)
                                    if (_canDoEnv) ...[
                                      _ChecklistCard(
                                        items: _envItems,
                                        counts: _counts,
                                        onAdjust: _adjust,
                                        onShowHistory: _showHistory,
                                      ),
                                      if (isDesktop) SizedBox(height: 16),
                                    ],
                                    // 내역 카드는 **점검 항목이 없는 사람**(대표·관리자)과
                                    // **데스크톱**에만 둔다.
                                    //
                                    // 폰에서 정비를 하는 사람은 점검 카드 머리말의 `총 N회` 를
                                    // 눌러 시트로 본다 — 그 아래 같은 내용을 또 깔면 화면만 길어진다.
                                    // 데스크톱은 그 자리가 눌리지 않는 글자라(`_ChecklistCard`)
                                    // 카드를 빼면 내역을 볼 길이 없어진다.
                                    // 대표·관리자는 '내 내역'이 **늘 비어 있다** — 서버가
                                    // 그들에게는 기록을 안 받는다(`_canDoEnv`). 빈 카드가
                                    // 절반을 차지하고 있었으므로 빼고 전체 내역을 넓힌다.
                                    if (isDesktop)
                                      if (_canDoEnv)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: _myHistoryCard),
                                            SizedBox(width: 16),
                                            Expanded(child: _allHistoryCard),
                                          ],
                                        )
                                      else
                                        _allHistoryCard
                                    else if (!_canDoEnv)
                                      _allHistoryCard,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            )
          else if (item.label == '동료 평가')
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _pad),
              child: PeerReviewSection(branchId: _branch),
            )
          else if (item.label == '수업 개수')
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _pad),
              child: LessonSection(branchId: _branch),
            )
          else if (item.label == '회원 친절도')
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _pad),
              child: PraiseSection(branchId: _branch),
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

/// 사진과 위치를 반드시 받는 항목 — **서버의 `PHOTO_REQUIRED_ITEMS` 와 같아야 한다**
///
/// 여기서 안 막아도 서버가 400 으로 되돌려 보내지만, 그러면 사용자는 누른 뒤에야
/// 알게 된다. 한쪽만 늘리면 그 항목이 눌러도 안 되는 칩이 되므로 같이 고친다.
const _photoRequiredItems = {'현수막', '족자'};

bool _needsPhoto(EnvItem item) => _photoRequiredItems
    .map(_WorkScreenState._envKey)
    .contains(_WorkScreenState._envKey(item.name));

/// 현수막처럼 확인이 필요한 항목의 `+` 를 눌렀을 때 뜨는 창
///
/// **사진과 위치를 둘 다 채워야 완료가 눌린다.** 걸었다고 칩만 누르면 실제로
/// 걸었는지 확인할 방법이 없어서 대표님이 요청한 자리다 (2026-08-18).
///
/// 사진은 **이 창 안에서 올리고** 끝나면 닫는다. 닫은 뒤에 올리면 몇 초 동안
/// 아무 표시가 없어서 칩을 다시 누르게 된다 — 완료 버튼이 스피너로 바뀌는
/// 편이 지금 무슨 일이 일어나는지 보인다.
class _PhotoProofCard extends StatefulWidget {
  _PhotoProofCard({required this.item});

  final EnvItem item;

  @override
  State<_PhotoProofCard> createState() => _PhotoProofCardState();
}

class _PhotoProofCardState extends State<_PhotoProofCard> {
  final _place = TextEditingController();

  /// 고른 사진 — 아직 안 올렸다
  String? _path;
  String? _name;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _place.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  bool get _ready => _path != null && _place.text.trim().isNotEmpty;

  Future<void> _pick() async {
    final picked = await FilePicker.pickFiles(
      type: isDesktop ? FileType.any : FileType.image,
      compressionQuality: isDesktop ? 0 : 100,
    );
    final file = picked?.files.firstOrNull;
    if (file?.path case final path?) {
      setState(() {
        _path = path;
        _name = file!.name;
      });
    }
  }

  /// 사진을 줄여 올리고 주소를 돌려준다 — 실패하면 창을 안 닫는다
  Future<void> _submit() async {
    if (!_ready || _busy) return;
    setState(() => _busy = true);
    try {
      // 사내톡 사진과 같은 규칙으로 줄인다 (원본 그대로 올리면 장당 몇 MB 다)
      final (path, name) = await shrinkPhoto(_path!, _name ?? 'photo.jpg');
      final url = await EnvApi.uploadPhoto(path, filename: name);
      if (!mounted) return;
      Navigator.pop(context, (url: url, place: _place.text.trim()));
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        AppToast.show(context, messageOf(error));
      }
    }
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
          Text('어디에 걸었나요?', style: AppTextStyles.title3),
          SizedBox(height: 6),
          Text(
            '${widget.item.name}은(는) 사진과 위치를 남겨야 기록돼요.',
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
          SizedBox(height: 14),
          _photoBox(),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _place,
              maxLength: _placeMaxLength,
              style: AppTextStyles.body1,
              cursorColor: AppColors.primary,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '예) 정문 앞 도로',
                hintStyle: AppTextStyles.body1.copyWith(
                  color: AppColors.gray400,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                counterText: '',
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
                  filled: _ready,
                  busy: _busy,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 사진 자리 — 고르기 전에는 점선 대신 회색 면에 안내, 고르면 미리보기
  Widget _photoBox() {
    return Pressable(
      onTap: _busy ? () {} : _pick,
      child: Container(
        height: 132,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _path == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.camera,
                    size: 22,
                    color: AppColors.gray400,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '사진 고르기',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              )
            : Image.file(File(_path!), fit: BoxFit.cover),
      ),
    );
  }
}

/// 남긴 사진을 보는 창 — 내역 줄을 누르면 뜬다
///
/// **한 장짜리라 사내톡 뷰어를 안 쓴다.** 그쪽(`chat_photo_viewer.dart`)은 여러 장을
/// 좌우로 넘기는 갤러리인 데다 `part of 'chat_screen.dart'` 라 밖에서 못 부른다 —
/// 꺼내려면 사내톡을 건드려야 해서 그러지 않았다.
///
/// 모양은 [_PhotoProofCard] 를 그대로 따라간다 (같은 폭·여백·라운드). 사진을
/// 남기는 창과 보는 창이 다르게 생기면 같은 것을 다루는 자리로 안 읽힌다.
class _PhotoLogCard extends StatefulWidget {
  _PhotoLogCard({required this.log});

  final EnvTaskLog log;

  @override
  State<_PhotoLogCard> createState() => _PhotoLogCardState();
}

class _PhotoLogCardState extends State<_PhotoLogCard> {
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final url = widget.log.photoUrl;
    if (url == null || url.isEmpty) {
      _failed = true;
      return;
    }
    // 한 번 받은 사진은 [PhotoCache] 가 들고 있어서 다음부터 바로 뜬다
    // (아바타·사내톡 사진과 같은 길이다)
    _file = PhotoCache.ready(url);
    if (_file != null) return;
    PhotoCache.fetch(url).then((file) {
      if (!mounted) return;
      setState(() {
        _file = file;
        _failed = file == null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final place = log.place;
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
          Text(log.itemName, style: AppTextStyles.title3),
          SizedBox(height: 6),
          Text(
            '${_LogRow.formatTime(log.createdAt)} · ${_logAuthor(log)}',
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
          SizedBox(height: 14),
          // 남길 때 쓰는 자리와 높이를 맞춘다 — 두 창이 같은 크기로 보여야 한다
          Container(
            height: 132,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _file != null
                ? Image.file(_file!, fit: BoxFit.cover)
                : Center(
                    child: _failed
                        ? Icon(
                            CupertinoIcons.photo,
                            size: 22,
                            color: AppColors.gray400,
                          )
                        : SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                  ),
          ),
          if (place != null && place.isNotEmpty) ...[
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(place, style: AppTextStyles.body1),
            ),
          ],
          SizedBox(height: 12),
          AppButton(label: '닫기', onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

/// 위치 입력 길이 — 기록에 그대로 남는 값이라 서버 컬럼(100)과 맞춘다
const _placeMaxLength = 30;

/// 수행 기록을 누가 남겼는지 — 서버는 직원 id 만 준다
String _logAuthor(EnvTaskLog log) =>
    StaffDirectory.instance.byId(log.employeeId)?.name ?? '알 수 없음';
