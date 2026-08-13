import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/env_api.dart';
import '../../core/data/branch_scope.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/util/sf_symbols.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/input/see_all_button.dart';
import '../../core/widgets/nav/desktop_header.dart';
import 'contribution/contribution_section.dart';
import 'lesson/lesson_section.dart';
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

class _WorkScreenState extends State<WorkScreen> with ScreenRefresh<WorkScreen> {
  int _tab = 0;

  /// 환경정비 항목과 배점 — 지점마다 다르다
  List<EnvItem> _envItems = const [];

  /// 오늘 지점에서 나온 수행 기록 전부 (내 것 + 동료 것)
  List<EnvTaskLog> _logs = const [];

  bool _envLoading = true;

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

  @override
  void initState() {
    super.initState();
    branchScope.addListener(_onBranchScope);
    _loadEnv();
  }

  @override
  void dispose() {
    branchScope.removeListener(_onBranchScope);
    super.dispose();
  }

  /// 헤더에서 지점을 바꿨다 — 이 화면이 들고 있는 것만 다시 받는다.
  /// 항목 화면들은 각자 `didUpdateWidget` 에서 다시 받는다.
  void _onBranchScope() {
    if (!mounted) return;
    setState(() => _envLoading = true);
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
        date: dateKey(DateTime.now()),
      );
      final items = await itemRequest;
      final logs = await logRequest;
      if (!mounted) return;
      setState(() {
        // 서버가 sortOrder 순으로 준다 — 앱이 다시 세우지 않는다
        _envItems = items;
        _logs = logs;
        _envLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _envLoading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 이름 비교용 열쇠 — 공백·대소문자를 지우고 맞춘다
  ///
  /// '기타'는 지점이 이름을 고칠 수 있어서 띄어쓰기 하나로 못 알아보는 일이
  /// 없게 해 둔다.
  static String _envKey(String name) => name.replaceAll(' ', '').toLowerCase();

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
      // 랭킹과 같이 **폭을 꽉 채워 균등하게** 나눈다.
      // 예전에는 글자 폭만큼만 잡고 왼쪽에 붙여 뒀는데, 넓은 화면에서
      // 오른쪽이 휑하게 남아 랭킹 탭과 결이 달랐다.
      return SegmentedTabs(
        labels: [for (final item in _items) item.label],
        selected: _tab,
        onSelect: (i) => setState(() => _tab = i),
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
              child: _envLoading
                  ? _ChecklistSkeleton()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _myHistoryCard),
                              SizedBox(width: 16),
                              Expanded(child: _allHistoryCard),
                            ],
                          )
                        else if (!_canDoEnv) ...[
                          _myHistoryCard,
                          SizedBox(height: 16),
                          _allHistoryCard,
                        ],
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

/// 수행 기록을 누가 남겼는지 — 서버는 직원 id 만 준다
String _logAuthor(EnvTaskLog log) =>
    StaffDirectory.instance.byId(log.employeeId)?.name ?? '알 수 없음';
