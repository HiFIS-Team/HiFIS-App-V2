import 'dart:async';

import 'package:flutter/cupertino.dart';
import '../../core/data/data_signal.dart';
import 'package:flutter/material.dart';

import '../../core/util/skeleton_delay.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/staff/payroll_api.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/display/person_card.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/feedback/reject_reason_dialog.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/widgets/glass/glass_bottom_button.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/widgets/input/decide_buttons.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/input/see_all_button.dart';
import '../../core/widgets/nav/desktop_header.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../../core/util/when.dart';
import '../../core/widgets/nav/pane_transition.dart';
import '../../core/util/screen_refresh.dart';

part 'salary_models.dart';
part 'salary_form.dart';
part 'salary_approval.dart';

/// 급여 화면 (목업)
///
/// 내 급여만 본다. 이번 달 받을 돈이 맨 위에 있고, 그 아래로 어떻게 그
/// 금액이 나왔는지(지급 → 공제) 순서대로 편다. 지난 달은 명세서 목록에서
/// 골라 같은 형식으로 다시 본다.
class SalaryScreen extends StatefulWidget {
  SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen>
    with ScreenRefresh<SalaryScreen>, SkeletonDelay<SalaryScreen> {
  /// 0 = 내 급여, 1 = 결재. 결재함을 볼 수 없는 사람에게는 탭 자체가 없다
  ///
  /// **MASTER·ADMIN 에게는 이 탭이 없다** — 화면 전체가 이미 결재 화면이다.
  int _tab = 0;

  /// 대표·관리자 결재함 — **할 일 기준으로 넷으로 가른다** (2026-08-31 요청)
  ///
  /// | 탭 | 담기는 것 | 여기서 하는 일 |
  /// |---|---|---|
  /// | 미제출 | `DRAFT` | 아직 안 낸 사람 — 볼 뿐이다 |
  /// | 승인 | `SUBMITTED` | **승인·반려** |
  /// | 반려 | `REJECTED` | 되돌려보낸 것 — 다시 낼 때까지 여기 있다 |
  /// | 지급 | `APPROVED` | **지급 처리** |
  ///
  /// **지급까지 끝난 것(`PAID`)은 어느 탭에도 안 선다** — 할 일이 없다.
  ///
  /// 줄을 섞지 않는 것이 이 구조의 뜻이다. 예전에는 한 줄에 이어 붙여 놓고
  /// `1/5` 로 넘겼는데, 승인하면 그 건이 지급 줄 끝으로 옮겨 가면서
  /// **보던 자리에 다른 사람이 들어왔다.**
  static const _boxLabels = ['미제출', '승인', '반려', '지급'];
  static const _boxStatuses = [
    PayslipStatus.draft,
    PayslipStatus.submitted,
    PayslipStatus.rejected,
    PayslipStatus.approved,
  ];

  /// 탭별 목록 — 위 차례와 같다
  List<List<Payslip>> _boxes = const [[], [], [], []];

  int _boxTab = 1;

  List<Payslip> get _box => _boxes[_boxTab];

  /// 탭에 다시 들어오거나 앱이 다시 앞으로 나왔을 때 조용히 다시 받는다
  @override
  Future<void> onScreenRefresh() => _load();

  /// 급여 결재함·내 명세서 상태가 바뀐다
  @override
  List<ValueNotifier<int>> get watchSignals => [
    approvalChanged,
    // 싸인을 찍으면 PT 커미션이 바로 오른다
    sessionSignChanged,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (_isPayBoss) {
        // 결재 대기(제출됨)가 먼저, 그다음 지급 대기(승인됨).
        // 대표·관리자는 자기 급여를 낼 일이 없어서 화면 전체가 이 사람들 것이다.
        // 두 함은 서로 상관없어서 한 번에 던진다 (하나씩 기다리면 왕복이 두 배)
        // 미제출까지 세워야 해서 상태를 안 가리고 한 번에 받는다.
        // 오래된 달은 자른다 — 안 자르면 해가 갈수록 목록이 는다
        final now = DateTime.now();
        final rows = await PayrollApi.all(
          from: yearMonthKey(DateTime(now.year, now.month - _monthsToLoad)),
        );
        _boxes = [
          for (final status in _boxStatuses)
            [
              for (final p in rows)
                if (p.status == status) p,
            ],
        ];
        // 보던 줄이 비면 뭐라도 있는 줄로 옮겨 준다 — 빈 칸을 보고 있을
        // 이유가 없다. 아무 데도 없으면 그대로 두고 빈 카드를 그린다
        //
        // **본인 명세서로 새지 않는다.** MASTER·ADMIN 은 급여를 받는 쪽이
        // 아니라 주는 쪽이라 본인 명세서가 아예 없다. 예전에는 결재함이 비면
        // 본인 화면으로 떨어져서, 마감 전 운영에서 대표 폰에
        // **`9월 급여 0원 · 9월 30일 지급 예정`** 이 떴다 (2026-09-01 지적).
        if (_box.isEmpty) {
          final found = _boxes.indexWhere((rows) => rows.isNotEmpty);
          if (found >= 0) _boxTab = found;
        }
      } else {
        await _loadPayslips();
      }
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(endLoad);
  }

  /// 신청 한 건을 열어 본다 — **그 사람 급여 화면이 통째로 뜬다**
  ///
  /// 처리하고 나오면 목록을 다시 받는다.
  Future<void> _openReview(Payslip payslip) async {
    await showFullPage<void>(context, (_) => _PayslipReview(payslip: payslip));
    if (!mounted) return;
    // 검토 화면이 전역 명세서 목록을 그 사람 것으로 채워 뒀다 — 되돌린다.
    // 처리했든 그냥 봤든 다시 받는다 (안 했으면 같은 값이 온다)
    await _load();
    if (mounted) setState(() {});
  }

  /// 대표·관리자 화면 — **줄 두 개와 이름 목록**
  ///
  /// 승인 대기와 지급 대기를 탭으로 가른다. 이름을 누르면 그 사람 급여
  /// 화면이 밀려 들어오고, 처리 버튼은 그 화면 아래에 붙는다
  /// (2026-08-31 대표 요청 — 예전에는 한 카드 안에서 `1/5` 로 넘겼다).
  Widget _boxScreen() {
    final tabs = SegmentedTabs(
      labels: _boxLabels,
      selected: _boxTab,
      onSelect: (i) => setState(() => _boxTab = i),
    );
    final list = PaneTransition(
      step: _boxTab,
      child: _PayrollBoxList(
        payslips: _box,
        status: _boxStatuses[_boxTab],
        onOpen: _openReview,
      ),
    );

    if (!isDesktop) {
      return PhoneListScaffold(title: '급여', filter: tabs, children: [list]);
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 64, 24, 32),
          children: [
            DesktopHeader(title: '급여', subtitle: '들어온 급여 신청을 결재해요'),
            SizedBox(height: 22),
            tabs,
            SizedBox(height: 16),
            list,
          ],
        ),
      ),
    );
  }

  void _openHistory(BuildContext context) {
    showFullPage<void>(context, (_) => _HistoryScreen());
  }

  /// 급여 신청서 작성 — 제출하면 대표 승인을 기다린다
  Future<void> _submit(_Payslip payslip) async {
    final done = await _showPayslipForm(context, payslip);
    if (done != true || !mounted) return;

    try {
      final submitted = await PayrollApi.submit(
        payslip.key,
        note: payslip.note,
        // 안 고쳤으면 null 이라 안 실린다 — 서버 계산값 그대로 쓴다
        incentiveNew: payslip.adjustNew,
        incentiveRenewal: payslip.adjustRenewal,
      );
      if (!mounted) return;
      setState(() {
        payslip.source = submitted;
        payslip.note = submitted.note;
      });
      AppToast.show(context, '${payslip.month.month}월 급여 신청서를 제출했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 제출 취소 — 승인 대기 중일 때만 된다
  ///
  /// 특이사항은 서버가 남겨 둬서 다시 신청할 때 그대로 뜬다.
  Future<void> _cancel(_Payslip payslip) async {
    try {
      final cancelled = await PayrollApi.cancel(payslip.key);
      if (!mounted) return;
      setState(() {
        payslip.source = cancelled;
        payslip.note = cancelled.note;
      });
      AppToast.show(context, '${payslip.month.month}월 급여 신청을 취소했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 대표·관리자는 **늘 결재함이다.** 본인 명세서를 안 받으므로 아래 뼈대
    // 조건(`_payslips.isEmpty`)에 걸리면 안 된다.
    // 빈 탭은 `_PayrollBoxList` 가 빈 카드로 그려 준다 — 화면이 비지 않는다
    if (_isPayBoss) return showSkeleton ? _BoxSkeleton() : _boxScreen();

    if (showSkeleton || _payslips.isEmpty) {
      if (!isDesktop) return _SalarySkeleton();
      return SkeletonDesktopPage(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SkeletonCard(
                  padding: EdgeInsets.all(20),
                  children: [
                    Skeleton(width: 84, height: 13),
                    SizedBox(height: 14),
                    Skeleton(width: 190, height: 30, radius: 8),
                    SizedBox(height: 12),
                    Skeleton(width: 140, height: 12),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: SkeletonCard(
                  padding: EdgeInsets.all(20),
                  children: [
                    Skeleton(width: 120, height: 13),
                    SizedBox(height: 14),
                    Skeleton(height: 11),
                    SizedBox(height: 16),
                    Skeleton(height: 48, radius: 14),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          SkeletonCard(
            padding: EdgeInsets.all(20),
            children: [
              Skeleton(width: 72, height: 14),
              SizedBox(height: 18),
              SkeletonRows(rows: 5, avatar: 0, trailing: 92),
            ],
          ),
        ],
      );
    }

    final current = _payslips.first;

    // 결재를 볼 수 있는 사람에게만 탭이 생긴다.
    // 나머지 사람 화면은 예전 그대로다 (탭 줄 자체가 없다).
    // MASTER·ADMIN 은 화면 전체가 결재 화면이라 탭이 필요 없다.
    // 점장은 본인 급여도 신청해서 예전처럼 탭으로 갈라 본다.
    final tabs = _canSeeApproval && !_isPayBoss
        ? SegmentedTabs(
            labels: const ['내 급여', '결재'],
            selected: _tab,
            onSelect: (i) => setState(() => _tab = i),
          )
        : null;

    // 폰은 이번 달 금액을 본 다음 바로 신청서를 낼 수 있게
    // 요약 카드 뒤에 신청 칸을 붙이고, 지난 흐름은 그 아래로 미룬다
    final content = [
      _SummaryCard(payslip: current),
      SizedBox(height: 12),
      // 여기까지 왔으면 들어온 신청이 없다 — 대표·관리자에게도 본인 화면이다
      if (!_isPayBoss) ...[
        _StatusNotice(
          payslip: current,
          onSubmit: () => _submit(current),
          onCancel: () => _cancel(current),
        ),
        SizedBox(height: 12),
      ],
      _TrendCard(),
      SizedBox(height: 12),
      _PayCard(payslip: current),
      SizedBox(height: 12),
      _HistoryCard(onOpenAll: () => _openHistory(context)),
    ];

    if (!isDesktop) {
      return PhoneListScaffold(
        title: '급여',
        filter: tabs,
        children: [
          // 탭이 있는 화면에서만 갈린다 — 탭이 없으면 step 이 안 바뀐다
          PaneTransition(
            step: _tab,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: tabs != null && _tab == 1 ? [_ApprovalTab()] : content,
            ),
          ),
        ],
      );
    }

    if (tabs != null && _tab == 1) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(24, 64, 24, 32),
            children: [
              DesktopHeader(
                title: '급여',
                subtitle: '이번 달 급여를 신청하고 지난 명세서를 확인해요',
              ),
              SizedBox(height: 22),
              tabs,
              SizedBox(height: 16),
              _ApprovalTab(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 64, 24, 32),
          children: [
            DesktopHeader(title: '급여', subtitle: '이번 달 급여를 신청하고 지난 명세서를 확인해요'),
            SizedBox(height: 22),
            if (tabs != null) ...[tabs, SizedBox(height: 16)],
            // 폭이 남으니 이번 달 요약과 추이를 나란히 둔다
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _SummaryCard(payslip: current)),
                  SizedBox(width: 16),
                  Expanded(child: _TrendCard()),
                ],
              ),
            ),
            SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _PayCard(payslip: current)),
                  SizedBox(width: 16),
                  // 여기까지 왔으면 들어온 신청이 없다 (있으면 목록 화면이다)
                  if (!_isPayBoss)
                    Expanded(
                      child: _StatusNotice(
                        payslip: current,
                        onSubmit: () => _submit(current),
                        onCancel: () => _cancel(current),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
            _HistoryCard(onOpenAll: () => _openHistory(context)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 이번 달 요약
// ---------------------------------------------------------------------------

/// 이번 달 실수령액 — 화면의 주인공
class _SummaryCard extends StatelessWidget {
  _SummaryCard({required this.payslip});

  final _Payslip payslip;

  @override
  Widget build(BuildContext context) {
    final paid = payslip.status == _PayStatus.paid;

    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '${payslip.month.month}월 급여',
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
              ),
              _StatusTag(status: payslip.status),
            ],
          ),
          SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _won(payslip.total),
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 6),
          Text(
            paid
                // 실제 입금일은 지급 예정일과 다를 수 있어 서버가 찍은 날을 쓴다
                ? '${_dayLabel(payslip.paidAt ?? payslip.payDay)} 지급 완료'
                : payslip.status == _PayStatus.approved
                ? '${_dayLabel(payslip.payDay)} 지급 예정 · D-${payslip.daysLeft}'
                // 아직 승인 전이라 확정 금액이 아니다
                : '${_dayLabel(payslip.payDay)} 지급 예정 (승인 전)',
            style: AppTextStyles.caption.copyWith(
              color: paid ? AppColors.textTertiary : AppColors.primary,
              fontWeight: paid ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
          SizedBox(height: 18),
          Container(height: 1, color: AppColors.divider),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_circle_fill,
                size: 13,
                color: AppColors.error,
              ),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  // 실제 입금액과 다르다는 걸 금액 바로 아래에서 알린다.
                  // 알바는 주휴수당이 아직 안 들어간 금액이라 같이 알린다.
                  payslip.hourly
                      ? '세금·보험 공제 전, 주휴수당 전 금액이에요'
                      : '세금·보험 공제 전 금액이에요',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  _StatusTag({required this.status});

  final _PayStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        // 상태 알약은 전부 완전한 알약이다 (프로젝트·일정·월차와 같다)
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: status.color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 최근 추이
// ---------------------------------------------------------------------------

/// 최근 6개월 총 지급액 막대 — 이번 달만 파랗게
class _TrendCard extends StatelessWidget {
  _TrendCard();

  @override
  Widget build(BuildContext context) {
    // 오래된 달이 왼쪽에 오도록 뒤집는다
    final months = _payslips.take(6).toList().reversed.toList();
    final top = months.map((p) => p.total).reduce((a, b) => a > b ? a : b);
    final average = months.isEmpty
        ? 0
        : months.fold(0, (sum, p) => sum + p.total) ~/ months.length;

    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('최근 6개월', style: AppTextStyles.label)),
              Text(
                '월평균 ${_won(average)}',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 18),
          SizedBox(
            // 금액(15) + 6 + 막대(최대 78) + 8 + 월(15)이 들어갈 높이
            height: 126,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final payslip in months)
                  Expanded(
                    child: _Bar(
                      payslip: payslip,
                      // 명세서가 아직 안 나온 달만 있으면 top 이 0이라
                      // 그냥 나누면 NaN 이 되고 막대 높이가 터진다
                      ratio: top == 0 ? 0 : payslip.total / top,
                      // 마지막(이번 달)만 색을 준다
                      current: payslip == months.last,
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

class _Bar extends StatelessWidget {
  _Bar({required this.payslip, required this.ratio, required this.current});

  final _Payslip payslip;
  final double ratio;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          // 만 원 단위로 줄여야 좁은 칸에 들어간다
          _amount(payslip.total ~/ 10000),
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: current ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
        SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Container(
            // 가장 높은 달을 78로 두고 비율로 깎는다
            height: 26 + 52 * ratio,
            decoration: BoxDecoration(
              color: current ? AppColors.primary : AppColors.gray100,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          '${payslip.month.month}월',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: current ? FontWeight.w700 : FontWeight.w400,
            color: current ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 지급 · 공제
// ---------------------------------------------------------------------------

/// 무엇을 받았는지 — 명세에 담겨 온 지급 항목을 그대로
class _PayCard extends StatelessWidget {
  _PayCard({required this.payslip});

  final _Payslip payslip;

  @override
  Widget build(BuildContext context) => _AmountCard(
    title: '지급',
    items: payslip.pays,
    total: payslip.total,
    totalLabel: '총 지급액',
    footnote: payslip.payNote,
    showFootnote: payslip.hasPayNote,
  );
}

/// 항목 나열 + 맨 아래 합계
class _AmountCard extends StatelessWidget {
  _AmountCard({
    required this.title,
    required this.items,
    required this.total,
    required this.totalLabel,
    required this.footnote,
    required this.showFootnote,
  });

  final String title;
  final List<_PayItem> items;
  final int total;
  final String totalLabel;

  /// 합계 아래 한 줄 설명 — 금액이 왜 이렇게 나왔는지
  final String footnote;

  /// 안 보일 때도 **자리는 그대로 잡는다** — 결재 화면에서 사람을 넘길 때마다
  /// 카드가 커졌다 작아졌다 하면 화면 전체가 위아래로 튄다
  final bool showFootnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.label),
          SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  // 항목과 근거를 한 덩어리로 묶어야 금액이 늘 같은 선에 선다.
                  // (설명을 Flexible로 두고 Spacer를 따로 쓰면 둘이 남는 폭을
                  //  나눠 가져서 금액 위치가 줄마다 달라진다)
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          item.label,
                          style: AppTextStyles.body2.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (item.note != null) ...[
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              item.note!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    _won(item.amount),
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 6),
          Container(height: 1, color: AppColors.divider),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  totalLabel,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Text(_won(total), style: AppTextStyles.title3),
            ],
          ),
          // 없을 때도 **같은 문장**으로 자리를 잡는다 — 짧은 빈칸으로 채우면
          // 두 줄로 접히는 문장과 높이가 어긋나서 결국 또 튄다
          SizedBox(height: 12),
          Opacity(
            opacity: showFootnote ? 1 : 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons.info_circle,
                  size: 13,
                  color: AppColors.gray400,
                ),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    footnote,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      height: 1.5,
                    ),
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

// ---------------------------------------------------------------------------
// 지난 명세서
// ---------------------------------------------------------------------------

/// 최근 5개월만 보여주고 나머지는 전체 보기에서
class _HistoryCard extends StatelessWidget {
  _HistoryCard({required this.onOpenAll});

  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    // 이번 달은 위에 이미 있으니 지난 달부터
    final past = _payslips.skip(1).take(5).toList();

    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 12),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('지난 명세서', style: AppTextStyles.label)),
              SeeAllButton(onTap: onOpenAll),
            ],
          ),
          SizedBox(height: 4),
          for (final payslip in past) _PayslipRow(payslip: payslip),
        ],
      ),
    );
  }
}

/// 명세서 한 줄 — 누르면 그달 명세서가 열린다
class _PayslipRow extends StatelessWidget {
  _PayslipRow({required this.payslip});

  final _Payslip payslip;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () =>
          showFullPage<void>(context, (_) => _PayslipDetail(payslip: payslip)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        // 월·세션·상태·금액을 한 줄에 세우면 폰 폭에 100pt 넘게 모자란다.
        // 예전엔 `Spacer()` 로 밀어 뒀는데, 자리가 없으면 Spacer 가 0이 되어
        // '지급 완료3,450,000원' 처럼 붙어 버렸다 (실제 발생).
        // 달을 위, 세션·상태를 아래로 내려 가로 압박 자체를 없앤다.
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _monthLabel(payslip.month),
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '세션 ${payslip.sessions}회',
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                      Text(
                        ' · ',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.gray300,
                        ),
                      ),
                      Text(
                        payslip.status.label,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: payslip.status.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Text(
              _won(payslip.total),
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.gray300,
            ),
          ],
        ),
      ),
    );
  }
}

/// 전체 명세서 목록
class _HistoryScreen extends StatelessWidget {
  _HistoryScreen();

  @override
  Widget build(BuildContext context) {
    // 연도가 바뀌는 자리에 머리말을 끼운다
    final children = <Widget>[];
    int? year;
    for (final payslip in _payslips) {
      if (payslip.month.year != year) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, year == null ? 0 : 18, 4, 6),
            child: Text(
              '${payslip.month.year}년',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        year = payslip.month.year;
      }
      children.add(
        Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: AppDecorations.card(radius: 16),
          child: _PayslipRow(payslip: payslip),
        ),
      );
    }

    return PhoneDetailScaffold(
      title: '급여 명세서',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: children,
      ),
    );
  }
}

/// 한 달 명세서 — 위 화면과 같은 구성으로 다시 보여준다
class _PayslipDetail extends StatelessWidget {
  _PayslipDetail({required this.payslip});

  final _Payslip payslip;

  @override
  Widget build(BuildContext context) {
    return PhoneDetailScaffold(
      title: '${_monthLabel(payslip.month)} 명세서',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          _SummaryCard(payslip: payslip),
          SizedBox(height: 12),
          _PayCard(payslip: payslip),
        ],
      ),
    );
  }
}
