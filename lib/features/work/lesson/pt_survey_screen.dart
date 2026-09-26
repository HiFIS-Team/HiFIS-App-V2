import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/pt_survey_api.dart';
import '../../../core/data/staff.dart';
import '../../../core/data/staff_directory.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/when.dart';
import '../../../core/util/skeleton_delay.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/delayed_spinner.dart';
import '../../../core/widgets/glass/glass_icon_button.dart';
import '../../../core/widgets/glass/glass_search_bar.dart';
import '../../../core/widgets/input/mode_switch.dart';
import '../../../core/api/client/period.dart';
import '../../../core/widgets/nav/month_bar.dart';
import '../../../core/widgets/nav/phone_scaffold.dart';
import '../../../core/widgets/nav/pick_filter_button.dart';
import '../../../core/widgets/input/pressable.dart';

/// PT 만족도 폼 결과 화면 — **회원 누적 7회차마다 열리는 설문을 보는 자리**
///
/// 서버는 진작에 `GET /pt-surveys` 를 열어 뒀는데 이걸 보는 화면이 앱에도
/// 웹에도 없었다 (2026-09-05). 폼은 회차마다 열리고 답도 들어오는데 아무도
/// 못 보고 있었다.
///
/// **볼 수 있는 사람이 서버에서 갈린다** (2026-09-09 대표 결정으로 바뀌었다).
///
/// | 누가 | 무엇을 |
/// |---|---|
/// | MASTER · ADMIN | **전부** |
/// | MANAGER · MEMBER | **본인이 수업한 것만** |
///
/// 예전에는 정반대였다 — 누구든 자기가 받은 평가는 못 봤고 트레이너는 403
/// 이었다. 회원 설문에 "트레이너에게는 전달되지 않아요" 라고 적어 두었기
/// 때문인데, **그 문구를 걷어내면서 같이 풀었다.**
///
/// **문자는 이제 자동으로 나간다** (2026-09-09). 7회차 싸인이 찍히면 그
/// 트레이너의 지점 번호로 설문 주소가 회원에게 간다. 다만 지점 발신번호가
/// 없거나 솔라피가 죽으면 안 나가므로, **미응답 줄의 주소 복사 버튼은
/// 그대로 둔다** — 손으로 넘기는 길이 없으면 그때 막힌다.
class PtSurveyScreen extends StatefulWidget {
  PtSurveyScreen({super.key, this.branchId});

  /// 업무 화면 지점 고르개가 정한 지점 — null 이면 볼 수 있는 만큼 다
  final String? branchId;

  @override
  State<PtSurveyScreen> createState() => _PtSurveyScreenState();
}

class _PtSurveyScreenState extends State<PtSurveyScreen>
    with SkeletonDelay<PtSurveyScreen> {
  final _search = TextEditingController();

  /// 0 답변 온 것 · 1 아직 안 낸 것
  ///
  /// 갈라 두는 이유가 있다. **미응답은 할 일이고 응답은 읽을 거리다** —
  /// 한 줄에 섞으면 다시 물어봐야 할 사람이 답변 사이에 묻힌다.
  int _tab = 0;

  List<PtSurvey> _rows = const [];

  /// 다시 받는 중 — 버튼을 잠가 두 번 누르는 걸 막는다
  bool _refreshing = false;

  /// 고른 트레이너 — null 이면 전체 (2026-09-09 대표 요청)
  ///
  /// **대표·관리자에게만 있다.** 나머지는 서버가 본인 것만 주므로 고를 것이 없다.
  String? _trainerId;

  /// 트레이너를 고를 수 있는가 — 대표·관리자만
  bool get _canFilter => myRole.boss;

  /// 보고 있는 달 — **기본은 이번 달** (2026-09-21 대표 요청)
  ///
  /// 예전에는 통째로 내려와서 쌓일수록 이번 달 것을 보려면 한참 내려야 했다.
  /// 환경정비 내역·세션 기록과 같은 달 이동 줄([MonthBar])을 쓴다.
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// 이번 달인가 — 앞으로는 더 갈 데가 없다
  bool get _isThisMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      beginLoad();
    });
    _load();
  }

  /// 고르개에 세울 사람 — **받아 온 줄에서 뽑는다**
  ///
  /// 명단(`StaffDirectory`) 전체를 세우면 설문이 하나도 없는 사람이 잔뜩
  /// 서는데, 골라 봐야 빈 화면이다. 여기 있는 사람이 곧 볼 것이 있는 사람이다.
  List<({String id, String name})> get _trainers {
    final seen = <String, String>{};
    for (final survey in _rows) {
      seen[survey.trainerId] = survey.displayTrainer;
    }
    final rows = [for (final e in seen.entries) (id: e.key, name: e.value)];
    rows.sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  /// 손으로 다시 받기 — 회원이 방금 낸 답을 보려고 화면을 닫았다 여는 일을 없앤다
  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _load();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  void didUpdateWidget(PtSurveyScreen old) {
    super.didUpdateWidget(old);
    if (old.branchId != widget.branchId) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // **한 번만 받아 앱에서 가른다.** `unanswered` 로 두 번 부르면 탭을
      // 옮길 때마다 기다리게 된다 — 어차피 등록권당 한 줄이라 양이 적다
      final rows = await PtSurveyApi.list(
        branchId: widget.branchId,
        // 달로 끊어 받는다 — 서버가 `created_at` 으로 자른다
        period: periodKey(_month),
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 문자가 나가기 전까지 손으로 넘기는 길 — 주소를 복사해 둔다
  Future<void> _copyLink(PtSurvey survey) async {
    if (survey.url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: survey.url));
    if (mounted) AppToast.show(context, '주소를 복사했어요 · 회원에게 보내세요');
  }

  bool _matches(PtSurvey survey, String query) {
    if (query.isEmpty) return true;
    return survey.displayMember.contains(query) ||
        survey.displayTrainer.contains(query) ||
        // 주제 문구와 상세를 같이 훑는다 — `식단` 으로 찾으면 그 주제를 고른
        // 답이 다 걸린다 (옛 서술형 답도 `allText` 에 들어 있다)
        survey.allText.contains(query);
  }

  List<PtSurvey> get _shown {
    final query = _search.text.trim();
    final wantAnswered = _tab == 0;
    return [
      for (final survey in _rows)
        if (survey.answered == wantAnswered)
          if (_trainerId == null || survey.trainerId == _trainerId)
            if (_matches(survey, query)) survey,
    ];
  }

  /// 지금 보이는 답변 중 **연장하겠다고 답한 비율** (2026-09-09 대표 요청)
  ///
  /// **'고민 중이에요' 는 안 센다.** 반만 세는 식으로 섞으면 그 숫자가 무엇인지
  /// 설명할 수 없어진다 — '연장할래요' 를 고른 사람의 비율 하나로 둔다.
  ///
  /// **화면에 보이는 줄로 센다** — 트레이너를 고르거나 검색해서 걸러 두면 그
  /// 만큼만 센다. 옆의 `총 N건` 과 같은 목록을 말해야 둘이 안 어긋난다.
  ///
  /// 답이 하나도 없으면 null 이다 (0으로 나눌 수 없다).
  int? _renewRate(List<PtSurvey> rows) {
    final decided = [
      for (final survey in rows)
        if (survey.renew != null) survey,
    ];
    if (decided.isEmpty) return null;
    final yes = decided.where((s) => s.renew == RenewIntent.yes).length;
    return (yes * 100 / decided.length).round();
  }

  /// '연장할래요' 로 답한 건의 등록 금액 — **다음달 예상 PT 매출**의 재료다
  /// (2026-09-15 대표 요청).
  ///
  /// '고민 중이에요'·미응답은 안 센다 — 아직 안 정해졌거나 안 온 것을 매출로
  /// 잡으면 부풀려 보인다. **트레이너를 골랐으면 그 사람 것만** 잡는다(고르개와
  /// 같은 범위). 검색어·응답/미응답 탭에는 영향받지 않는다 — 찾는 글자와
  /// 상관없이 이번 지점(트레이너) 전망은 그대로여야 한다.
  ///
  /// **보고 있는 달에 답한 것만 센다.** 안 자르면 반년 전에 '연장할래요' 라고
  /// 답한 건까지 계속 얹혀 **'다음달' 예상 매출이 달마다 불어나기만 한다** —
  /// 그달에 연장하겠다고 한 사람이 다음 달에 결제한다는 뜻이라 답한 달로 자른다.
  ///
  /// **`_month` 를 본다 (오늘이 아니라).** 서버는 `created_at` 으로 끊어 주는데
  /// 답한 때는 그보다 늦을 수 있어서, 여기서 한 번 더 답한 달로 맞춘다 —
  /// 안 맞추면 지난 달을 보는데 예상 매출만 이번 달 것이 뜬다.
  ///
  /// **회원당 한 번만 센다** (2026-09-27). 설문이 7회차마다 와서 한 달에
  /// 7·14회차 둘 다 '연장할래요' 일 수 있다 — 같은 사람의 연장을 두 번 더하면
  /// 예상 매출이 부푼다. 그 달에 **마지막으로 답한 것**을 남긴다.
  List<PtSurvey> get _renewedRows {
    final byMember = <String, PtSurvey>{};
    for (final survey in _rows) {
      final at = survey.answeredAt;
      if (at == null || at.year != _month.year || at.month != _month.month) {
        continue;
      }
      if (_trainerId != null && survey.trainerId != _trainerId) continue;
      final kept = byMember[survey.memberId];
      if (kept == null || at.isAfter(kept.answeredAt!)) {
        byMember[survey.memberId] = survey;
      }
    }
    return [
      for (final survey in byMember.values)
        if (survey.renew == RenewIntent.yes) survey,
    ];
  }

  int get _revenueTotal =>
      _renewedRows.fold(0, (sum, s) => sum + (s.pricePaid ?? 0));

  /// 트레이너별 합계 — 이름 오름차순
  List<({String name, int amount})> get _revenueByTrainer {
    final sums = <String, int>{};
    for (final s in _renewedRows) {
      sums[s.displayTrainer] =
          (sums[s.displayTrainer] ?? 0) + (s.pricePaid ?? 0);
    }
    final rows = [for (final e in sums.entries) (name: e.key, amount: e.value)];
    rows.sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }

  /// 지점별 합계 — **트레이너를 안 골랐고 여러 지점이 섞여 있을 때만** 쓴다
  /// (대표·관리자가 '전체 지점' 으로 볼 때). 지점이 하나뿐이면 트레이너별
  /// 목록이 곧 그 지점 것이라 따로 안 보여준다.
  ///
  /// **지점은 0원이어도 다 세운다** (2026-09-16 대표 결정). 매출이 있는 곳만
  /// 세우면 그 달에 연장 답변이 없던 지점이 통째로 사라져서, 읽는 쪽이
  /// **'빠진 건지 없는 건지'** 를 못 가른다. 늘 같은 자리에 서 있어야 한다.
  ///
  /// **HQ(전 지점)는 매출이 있을 때만 세운다** — 소속이 대표·관리자·마케터라
  /// 수업을 안 해서 늘 0원인 줄이 하나 붙는 꼴이 된다.
  /// 실제로 매출이 잡힌 지점이 몇 곳인가 — **0원으로 깔아 둔 줄은 안 센다.**
  /// [_revenueByBranch] 는 지점을 다 세우므로 그 길이로는 이걸 못 판단한다.
  int get _branchesWithRevenue => {
    for (final s in _renewedRows)
      if ((s.branchName ?? '').trim().isNotEmpty && (s.pricePaid ?? 0) > 0)
        s.branchName!.trim(),
  }.length;

  List<({String name, int amount})> get _revenueByBranch {
    final sums = <String, int>{};
    // 먼저 지점을 0원으로 깔아 둔다 — 명단을 못 받았으면(로그인 전·서버 꺼짐)
    // 아래 합산에 나온 곳만 선다
    final directory = StaffDirectory.instance;
    for (final branch in directory.branches) {
      if (!branch.isHq) sums[branch.name] = 0;
    }
    for (final s in _renewedRows) {
      final name = s.branchName?.trim();
      if (name == null || name.isEmpty) continue;
      sums[name] = (sums[name] ?? 0) + (s.pricePaid ?? 0);
    }
    final rows = [for (final e in sums.entries) (name: e.key, amount: e.value)];
    // 지점 차례는 조직도·랭킹과 같은 규칙을 쓴다 (화순 → 첨단)
    rows.sort((a, b) {
      final rank = directory
          .branchRank(directory.branchIdOf(a.name))
          .compareTo(directory.branchRank(directory.branchIdOf(b.name)));
      return rank != 0 ? rank : a.name.compareTo(b.name);
    });
    return rows;
  }

  /// 줄을 세우는 기준값 — 답변은 답한 때, 미응답은 열린 때다
  DateTime _sortKey(PtSurvey survey) => survey.answeredAt ?? survey.createdAt;

  /// 차례를 매긴다 — **두 탭이 반대 방향이다**
  ///
  /// 답변은 새것이 위다 (방금 온 것을 읽는 자리다).
  /// 미응답은 **오래된 것이 위다** — 제일 오래 기다린 사람이 먼저 챙겨야 할
  /// 사람이라, 새것부터 세우면 정작 잊힌 줄이 맨 아래로 가라앉는다.
  int _compare(PtSurvey a, PtSurvey b) => _tab == 0
      ? _sortKey(b).compareTo(_sortKey(a))
      : _sortKey(a).compareTo(_sortKey(b));

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final sorted = _shown..sort(_compare);
    final answered = _tab == 0;
    // 미응답 탭에는 연장 답이 없다 — 셀 것이 없으므로 아예 안 그린다
    final renewRate = answered ? _renewRate(sorted) : null;

    // 날짜가 바뀌는 지점마다 그룹 헤더를 끼워 넣는다 — 세션 기록·설문 응답과 같다
    final children = <Widget>[];
    String? label;
    for (final survey in sorted) {
      final day = dayLabel(_sortKey(survey));
      if (day != label) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, label == null ? 4 : 22, 4, 4),
            child: Text(
              day,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        label = day;
      } else {
        children.add(Divider(height: 1, color: AppColors.divider));
      }
      children.add(
        _PtSurveyRow(
          survey: survey,
          onTap: () => _showPtSurveyDetail(context, survey),
          onCopy: survey.answered ? null : () => _copyLink(survey),
        ),
      );
    }

    return PhoneDetailScaffold(
      title: 'PT 만족도',
      // **대표·관리자는 트레이너 고르개** (2026-09-09 요청).
      // 전사가 한 목록에 서면 누구 것을 보는 중인지가 흐려진다.
      //
      // 나머지는 본인 것만 오므로 고를 것이 없다 — 그 자리에 예전처럼
      // 다시 받기를 둔다. **밖에서 들어오는 값**이라 다시 받는 길이 있어야
      // 한다 (주소를 보내 놓고 답이 왔나 보는 자리다).
      actions: [
        if (_canFilter)
          PickFilterButton(
            stableId: 'pt-trainer',
            options: [for (final t in _trainers) (id: t.id, name: t.name)],
            selected: _trainerId,
            onSelect: (id) => setState(() => _trainerId = id),
          )
        else
          GlassIconButton(
            symbol: 'arrow.clockwise',
            onPressed: _refreshing ? null : _refresh,
          ),
      ],
      // 하단 고정: 플로팅 글래스 검색 바 (키보드와 함께 상승)
      bottomBar: GlassSearchBar(controller: _search, hint: '회원·트레이너·내용 검색'),
      // **탭·예상 매출까지 한 스크롤이다** (2026-09-16 대표 요청).
      // 예전에는 머리를 고정해 두고 목록만 굴렀는데, 그러면 위 블러 뒤로
      // 콘텐츠가 지나가는 결이 안 살고 회원 정보·조직도와 모양이 달랐다.
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          // 하단 글래스 검색 바에 가리지 않도록 여유를 둔다
          MediaQuery.paddingOf(context).bottom + 96,
        ),
        children: [
          SegmentedTabs(
            labels: ['답변', '미응답'],
            selected: _tab,
            onSelect: (i) => setState(() => _tab = i),
          ),
          SizedBox(height: 10),
          // 달 이동 — 환경정비 내역·세션 기록과 **같은 줄**이다 (2026-09-21).
          // 건수는 아래 머리말이 이미 말하고 있어서 여기서는 안 그린다
          MonthBar(
            month: _month,
            count: 0,
            showCount: false,
            loading: false,
            padding: EdgeInsets.zero,
            onPrev: () => _moveMonth(-1),
            // 오지 않은 달에는 설문이 없다 — 앞으로는 못 간다
            onNext: _isThisMonth ? null : () => _moveMonth(1),
          ),
          SizedBox(height: 12),
          if (_revenueTotal > 0) ...[
            _RevenueForecastCard(
              total: _revenueTotal,
              // 트레이너를 골랐으면 이미 한 사람 것만 보는 중이라 줄이 필요 없다.
              // 지점이 여럿 섞여 있으면(전체 지점) 지점별로, 하나면 트레이너별로 가른다
              rows: _trainerId != null
                  ? const []
                  : _branchesWithRevenue > 1
                  ? _revenueByBranch
                  : _revenueByTrainer,
            ),
            SizedBox(height: 12),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    answered
                        ? '신규 회원 7회차에 받은 만족도'
                        : '아직 답을 안 준 회원 · 주소를 복사해 보내요',
                    style: AppTextStyles.caption,
                  ),
                ),
                if (renewRate != null) ...[
                  Text(
                    '재등록 $renewRate%',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    ' · ',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                Text(
                  '총 ${sorted.length}건',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.gray100),
          if (showSkeleton)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: DelayedSpinner.bare()),
            )
          else if (sorted.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 32, 4, 44),
              child: Text(
                query.isNotEmpty
                    ? '검색 결과가 없어요'
                    : answered
                    ? '아직 들어온 답변이 없어요'
                    : '기다리는 설문이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

/// 목록 한 줄 — 아바타 · 회원/트레이너 · 만족도·연장 꼬리표
class _PtSurveyRow extends StatelessWidget {
  _PtSurveyRow({required this.survey, required this.onTap, this.onCopy});

  final PtSurvey survey;
  final VoidCallback onTap;

  /// 미응답 줄에만 있다 — 문자가 나가기 전까지 손으로 넘기는 길
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final color = avatarColorFor(survey.displayMember);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                survey.displayMember.characters.first,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    survey.displayMember,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${survey.displayTrainer} · ${survey.sessionNo}회차',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            if (survey.answered) ...[
              if (survey.satisfaction case final score?)
                _PtTag(label: '만족 $score', color: AppColors.primary),
              if (survey.renew case final renew?) ...[
                SizedBox(width: 6),
                _PtTag(label: renew.label, color: _renewColor(renew)),
              ],
            ] else
              // 문자가 나가기 전까지 손으로 넘기는 길 — 회원 수업 주소 카드와 같은 모양이다
              Pressable(
                onTap: onCopy ?? () {},
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    '주소 복사',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 다음달 예상 PT 매출 — '연장할래요' 로 답한 등록권의 결제액을 합친 것
/// (2026-09-15 대표 요청). [rows] 가 비어 있으면 합계만 보여준다.
class _RevenueForecastCard extends StatelessWidget {
  _RevenueForecastCard({required this.total, required this.rows});

  final int total;
  final List<({String name, int amount})> rows;

  /// 자릿수가 달라도 세로로 떨어지게 — `500,000` 과 `12,621,212` 가
  /// 글자폭이 제각각이면 지점 줄의 오른쪽 끝이 들쭉날쭉해 보인다
  static const _figures = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **무엇 → 얼마 → 무슨 근거** 순으로 쌓는다. 예전에는 제목과 금액이
          // 한 줄에서 자리를 다퉈서, 여덟 자리 금액이 제목을 밀어붙였다.
          Text(
            '다음달 예상 PT 매출',
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            '${_comma(total)}원',
            style: AppTextStyles.title1.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.success,
              height: 1.15,
              letterSpacing: -0.5,
              fontFeatures: _figures,
            ),
          ),
          SizedBox(height: 4),
          // 무엇을 더한 숫자인지 안 적으면 읽는 사람이 범위를 못 짚는다
          Text(
            "이번 달 '연장할래요' 답변 기준",
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
          // 합계와 지점 내역은 다른 값이라 가는 선으로 끊는다
          if (rows.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppColors.success.withValues(alpha: 0.16),
              ),
            ),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].name,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    '${_comma(rows[i].amount)}원',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFeatures: _figures,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// 1,000 단위 콤마 표기
String _comma(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// 연장 의향 색 — **연장 안 한다는 답이 눈에 띄어야 한다** (붙잡을 시간이 남았다)
Color _renewColor(RenewIntent renew) => switch (renew) {
  RenewIntent.yes => AppColors.success,
  RenewIntent.maybe => AppColors.warning,
  RenewIntent.no => AppColors.error,
};

class _PtTag extends StatelessWidget {
  _PtTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 답변 크게 보기 — 받은 문항을 순서대로 그대로 보여준다
void _showPtSurveyDetail(BuildContext context, PtSurvey survey) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'PT 만족도 크게 보기',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: _PtSurveyDetailCard(survey: survey),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _PtSurveyDetailCard extends StatelessWidget {
  _PtSurveyDetailCard({required this.survey});

  final PtSurvey survey;

  @override
  Widget build(BuildContext context) {
    // 좁은 화면에서는 화면 폭에 맞춘다
    final width = MediaQuery.sizeOf(context).width - 40;
    final when = survey.answeredAt ?? survey.createdAt;

    return Container(
      width: width < 320 ? width : 320,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatarColorFor(survey.displayMember),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    survey.displayMember.characters.first,
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        survey.displayMember,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${survey.displayTrainer} · ${survey.sessionNo}회차 · '
                        '${dayLabel(when)}',
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 18),
            if (!survey.answered)
              _PtField(
                label: '상태',
                value: '아직 답을 안 줬어요',
                valueColor: AppColors.textTertiary,
              )
            else ...[
              _PtField(
                label: '만족도',
                value: survey.satisfaction == null
                    ? ''
                    : '${survey.satisfaction} / 5',
              ),
              // **새 답은 객관식이고 옛 답은 서술형 한 칸이다** (2026-09-16).
              // 둘 다 그릴 줄 알아야 한다 — 갈아타기 전에 받은 답이 22건 있다
              if (survey.praise.isNotEmpty || survey.improve.isNotEmpty) ...[
                if (survey.praise.isNotEmpty)
                  _PtPicks(label: '좋았던 점', rows: survey.praise),
                if (survey.improve.isNotEmpty)
                  _PtPicks(label: '보완할 점', rows: survey.improve),
              ] else
                _PtField(
                  label: '앞으로 트레이너에게 바라는 점',
                  value: survey.request ?? '',
                ),
              _PtField(
                label: '연장 여부',
                value: survey.renew?.label ?? '',
                valueColor: survey.renew == null
                    ? null
                    : _renewColor(survey.renew!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 객관식 답 한 묶음 — 고른 주제와 그 아래 적은 글
///
/// **좋았던 점·보완할 점이 같은 모양이다.** 색으로 가르지 않는다 —
/// 포인트 컬러 하나 원칙이고, 어느 쪽인지는 머리말이 말해 준다.
class _PtPicks extends StatelessWidget {
  const _PtPicks({required this.label, required this.rows});

  final String label;
  final List<PtTopicAnswer> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          for (final row in rows)
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 6),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  // **글은 안 적어도 된다** — 주제만 고르고 넘어간 것이라
                  // 빈 줄을 그리면 '안 적었어요' 가 주제 수만큼 늘어선다
                  if ((row.note ?? '').trim().isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      row.note!.trim(),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 문항 한 칸 — 라벨 위, 값 아래. 빈 값은 흐리게 둔다
class _PtField extends StatelessWidget {
  _PtField({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value.isEmpty ? '적지 않았어요' : value,
            style: AppTextStyles.body2.copyWith(
              height: 1.5,
              color:
                  valueColor ??
                  (value.isEmpty
                      ? AppColors.textTertiary
                      : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
