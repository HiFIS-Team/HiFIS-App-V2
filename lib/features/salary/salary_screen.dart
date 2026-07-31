import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/phone_scaffold.dart';
import '../../core/widgets/pressable.dart';

part 'salary_models.dart';

/// 급여 화면 (목업)
///
/// 내 급여만 본다. 이번 달 받을 돈이 맨 위에 있고, 그 아래로 어떻게 그
/// 금액이 나왔는지(지급 → 공제) 순서대로 편다. 지난 달은 명세서 목록에서
/// 골라 같은 형식으로 다시 본다.
class SalaryScreen extends StatelessWidget {
  SalaryScreen({super.key});

  void _openHistory(BuildContext context) {
    showFullPage<void>(context, (_) => _HistoryScreen());
  }

  @override
  Widget build(BuildContext context) {
    final current = _payslips.first;

    final content = [
      _SummaryCard(payslip: current),
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
                  Expanded(flex: 3, child: _SummaryCard(payslip: current)),
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
    final scheduled = payslip.status == _PayStatus.scheduled;

    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${payslip.month.month}월 급여',
                  style: AppTextStyles.label,
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
            scheduled
                ? '${_dayLabel(payslip.payDay)} 지급 예정 · D-${payslip.daysLeft}'
                : '${_dayLabel(payslip.payDay)} 지급 완료',
            style: AppTextStyles.caption.copyWith(
              color: scheduled ? AppColors.primary : AppColors.textTertiary,
              fontWeight: scheduled ? FontWeight.w600 : FontWeight.w400,
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
        color: status == _PayStatus.paid
            ? AppColors.gray50
            : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: status == _PayStatus.paid
              ? AppColors.gray500
              : AppColors.primary,
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
            height: 96,
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

/// 무엇을 받았는지 — 기본급 + 수당 + 인센티브
class _PayCard extends StatelessWidget {
  _PayCard({required this.payslip});

  final _Payslip payslip;

  @override
  Widget build(BuildContext context) {
    return _AmountCard(
      title: '지급',
      total: payslip.gross,
      totalLabel: '지급 합계',
      rows: [
        ('기본급', null, payslip.base),
        (
          'PT 세션 수당',
          '${payslip.sessions}회 × ${_amount(_Payslip.sessionRate)}',
          payslip.sessionPay,
        ),
        (
          '신규 등록',
          '${payslip.newSignups}건 × ${_amount(_Payslip.newBonus)}',
          payslip.newPay,
        ),
        (
          '재등록',
          '${payslip.reSignups}건 × ${_amount(_Payslip.reBonus)}',
          payslip.rePay,
        ),
        ('식대', '비과세', _Payslip.meal),
      ],
    );
  }
}

/// 무엇을 뗐는지 — 4대보험 + 세금
class _DeductCard extends StatelessWidget {
  _DeductCard({required this.payslip});

  final _Payslip payslip;

  @override
  Widget build(BuildContext context) {
    return _AmountCard(
      title: '공제',
      total: payslip.deduction,
      totalLabel: '공제 합계',
      minus: true,
      rows: [
        ('국민연금', '4.5%', payslip.pension),
        ('건강보험', '3.545%', payslip.health),
        ('장기요양', '건강보험의 12.95%', payslip.care),
        ('고용보험', '0.9%', payslip.employment),
        ('소득세', null, payslip.incomeTax),
        ('지방소득세', '소득세의 10%', payslip.localTax),
      ],
    );
  }
}

/// 항목 나열 + 맨 아래 합계
class _AmountCard extends StatelessWidget {
  _AmountCard({
    required this.title,
    required this.rows,
    required this.total,
    required this.totalLabel,
    this.minus = false,
  });

  final String title;

  /// (항목, 계산 근거, 금액)
  final List<(String, String?, int)> rows;
  final int total;
  final String totalLabel;

  /// 공제처럼 빼는 금액이면 앞에 −를 붙인다
  final bool minus;

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
          for (final (label, note, value) in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (note != null) ...[
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                  Spacer(),
                  SizedBox(width: 8),
                  Text(
                    minus ? '−${_won(value)}' : _won(value),
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
              Text(
                totalLabel,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Spacer(),
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
