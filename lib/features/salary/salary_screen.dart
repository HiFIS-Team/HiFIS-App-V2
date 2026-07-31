import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/glass_bottom_button.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/phone_scaffold.dart';
import '../../core/widgets/pressable.dart';

part 'salary_models.dart';
part 'salary_form.dart';

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

class _SalaryScreenState extends State<SalaryScreen> {
  void _openHistory(BuildContext context) {
    showFullPage<void>(context, (_) => _HistoryScreen());
  }

  /// 급여 신청서 작성 — 제출하면 대표 승인을 기다린다
  Future<void> _submit(_Payslip payslip) async {
    final done = await _showPayslipForm(context, payslip);
    if (done != true || !mounted) return;
    setState(() {});
    AppToast.show(context, '${payslip.month.month}월 급여 신청서를 제출했어요');
  }

  Future<void> _cancel(_Payslip payslip) async {
    final ok = await showConfirmDialog(
      context,
      title: '제출을 취소할까요?',
      message: '대표에게 올린 신청서가 사라지고 다시 작성해야 해요.',
      confirmLabel: '취소하기',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      payslip
        ..status = _PayStatus.draft
        ..submittedAt = null;
    });
    AppToast.show(context, '제출을 취소했어요');
  }

  @override
  Widget build(BuildContext context) {
    final current = _payslips.first;

    final content = [
      _SummaryCard(payslip: current),
      SizedBox(height: 12),
      _StatusNotice(
        payslip: current,
        onSubmit: () => _submit(current),
        onCancel: () => _cancel(current),
      ),
      SizedBox(height: 12),
      _TrendCard(),
      SizedBox(height: 12),
      _PayCard(payslip: current),
      SizedBox(height: 12),
      _DeductCard(payslip: current),
      SizedBox(height: 12),
      _HistoryCard(onOpenAll: () => _openHistory(context)),
    ];

    if (!isDesktop) {
      return PhoneListScaffold(title: '급여', children: content);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 64, 24, 32),
          children: [
            Text('급여', style: AppTextStyles.title1),
            SizedBox(height: 20),
            // 폭이 남으니 이번 달 요약과 추이를 나란히 둔다
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryCard(payslip: current),
                        SizedBox(height: 16),
                        _StatusNotice(
                          payslip: current,
                          onSubmit: () => _submit(current),
                          onCancel: () => _cancel(current),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(flex: 4, child: _TrendCard()),
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
                  Expanded(child: _DeductCard(payslip: current)),
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
      padding: EdgeInsets.fromLTRB(22, 20, 22, 22),
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
                    SizedBox(width: 8),
                    // 어떤 조건으로 계산된 금액인지 밝힌다
                    Flexible(
                      child: Text(
                        '${payslip.type.label} · ${payslip.insuranceLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
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
              _won(payslip.net),
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
                ? '${_dayLabel(payslip.payDay)} 지급 완료'
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
          SizedBox(height: 14),
          Row(
            children: [
              _part('지급', payslip.gross, AppColors.textPrimary),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '−',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              _part('공제', payslip.deduction, AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _part(String label, int value, Color color) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
        SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _won(value),
            maxLines: 1,
            style: AppTextStyles.body1.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
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
        borderRadius: BorderRadius.circular(8),
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

/// 최근 6개월 실수령액 막대 — 이번 달만 파랗게
class _TrendCard extends StatelessWidget {
  _TrendCard();

  @override
  Widget build(BuildContext context) {
    // 오래된 달이 왼쪽에 오도록 뒤집는다
    final months = _payslips.take(6).toList().reversed.toList();
    final top = months.map((p) => p.net).reduce((a, b) => a > b ? a : b);
    final average = months.fold(0, (sum, p) => sum + p.net) ~/ months.length;

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
            // 금액(15) + 6 + 막대(최대 60) + 8 + 월(15)이 들어갈 높이
            height: 108,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final payslip in months)
                  Expanded(
                    child: _Bar(
                      payslip: payslip,
                      ratio: payslip.net / top,
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
          _amount(payslip.net ~/ 10000),
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
            // 가장 높은 달을 60으로 두고 비율로 깎는다
            height: 20 + 40 * ratio,
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
    total: payslip.gross,
    totalLabel: '지급 합계',
  );
}

/// 무엇을 뗐는지 — 고용 형태에 따라 항목이 다르고, 없을 수도 있다
class _DeductCard extends StatelessWidget {
  _DeductCard({required this.payslip});

  final _Payslip payslip;

  @override
  Widget build(BuildContext context) => _AmountCard(
    title: '공제',
    items: payslip.deductions,
    total: payslip.deduction,
    totalLabel: '공제 합계',
    minus: true,
    empty: '떼는 금액이 없어요',
  );
}

/// 항목 나열 + 맨 아래 합계
class _AmountCard extends StatelessWidget {
  _AmountCard({
    required this.title,
    required this.items,
    required this.total,
    required this.totalLabel,
    this.minus = false,
    this.empty,
  });

  final String title;
  final List<_PayItem> items;
  final int total;
  final String totalLabel;

  /// 공제처럼 빼는 금액이면 앞에 −를 붙인다
  final bool minus;

  /// 항목이 하나도 없을 때 대신 보여줄 안내
  final String? empty;

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
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                empty ?? '항목이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
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
                    minus ? '−${_won(item.amount)}' : _won(item.amount),
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
              Text(
                minus ? '−${_won(total)}' : _won(total),
                style: AppTextStyles.title3.copyWith(
                  color: minus ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ],
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
              Pressable(
                onTap: onOpenAll,
                scale: 0.94,
                child: Row(
                  children: [
                    Text(
                      '전체 보기',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.gray400,
                    ),
                  ],
                ),
              ),
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
      scale: 0.99,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                _monthLabel(payslip.month),
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '세션 ${payslip.sessions}회',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
            SizedBox(width: 8),
            Text(
              payslip.status.label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: payslip.status.color,
              ),
            ),
            Spacer(),
            Text(
              _won(payslip.net),
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
          SizedBox(height: 12),
          _DeductCard(payslip: payslip),
        ],
      ),
    );
  }
}
