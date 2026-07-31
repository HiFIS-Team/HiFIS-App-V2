import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/empty_card.dart';
import '../../core/widgets/phone_scaffold.dart';
import '../../core/widgets/placeholder_screen.dart';
import '../../core/widgets/pressable.dart';

part 'staff_models.dart';

/// 직원 화면 (목업)
///
/// 지점 구성원을 한눈에 보고 누구에게 연락할지 정하는 화면이다.
/// 카드마다 지금 상태(근무중·회의중·외출…)가 보이고, 누르면 연락처와
/// 이번 달 근태 요약이 뜬다. 폰은 아직 진입점이 없어 PC를 먼저 만든다.
class StaffScreen extends StatefulWidget {
  StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  String _query = '';
  String _team = '전체';

  List<_Member> get _visible {
    final query = _query.trim();
    return _members.where((m) {
      if (_team != '전체' && m.team != _team) return false;
      if (query.isEmpty) return true;
      // 이름·직무·팀 아무 데나 걸리면 보여준다
      return m.name.contains(query) ||
          m.role.contains(query) ||
          m.team.contains(query);
    }).toList();
  }

  void _open(_Member member) {
    showFullPage<void>(context, (_) => _MemberDetail(member: member));
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return PlaceholderScreen(emoji: '👥', title: '직원');

    final list = _visible;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 64, 24, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('직원', style: AppTextStyles.title1),
                SizedBox(width: 10),
                Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${_members.length}명',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _StatusSummary(),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TeamChips(
                    selected: _team,
                    onSelect: (team) => setState(() => _team = team),
                  ),
                ),
                SizedBox(width: 12),
                _SearchBox(onChanged: (q) => setState(() => _query = q)),
              ],
            ),
            SizedBox(height: 16),
            if (list.isEmpty)
              EmptyCard(icon: CupertinoIcons.person_2, text: '찾는 직원이 없어요')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  // 카드가 너무 넓어지지 않게 최소 폭 기준으로 열 수를 잡는다
                  const min = 268.0;
                  const gap = 16.0;
                  final columns = ((constraints.maxWidth + gap) / (min + gap))
                      .floor()
                      .clamp(1, 4);
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final member in list)
                        SizedBox(
                          width: width,
                          child: _MemberCard(
                            member: member,
                            onTap: () => _open(member),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 상단 요약
// ---------------------------------------------------------------------------

/// 지금 몇 명이 나와 있는지 — 상태를 네 갈래로 묶어 보여준다
class _StatusSummary extends StatelessWidget {
  _StatusSummary();

  @override
  Widget build(BuildContext context) {
    final present = _members.where((m) => m.status.present).length;
    final stepped = _members.where((m) => m.status.stepped).length;
    final leave = _members.where((m) => m.status == _Status.leave).length;
    final off = _members.where((m) => m.status == _Status.off).length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          _stat('근무중', present, AppColors.success),
          _divider(),
          _stat('자리 비움', stepped, AppColors.warning),
          _divider(),
          _stat('월차', leave, AppColors.primary),
          _divider(),
          _stat('퇴근', off, AppColors.textPrimary),
        ],
      ),
    );
  }

  Widget _stat(String label, int count, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          '$count명',
          style: AppTextStyles.title3.copyWith(fontSize: 19, color: color),
        ),
        SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 32, color: AppColors.gray100);
}

// ---------------------------------------------------------------------------
// 필터 · 검색
// ---------------------------------------------------------------------------

class _TeamChips extends StatelessWidget {
  _TeamChips({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final team in _teams)
          Pressable(
            onTap: () => onSelect(team),
            scale: 0.96,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 140),
              height: 34,
              padding: EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: team == selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: team == selected
                      ? AppColors.primary
                      : AppColors.gray200,
                ),
              ),
              child: Text(
                team,
                style: AppTextStyles.label.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: team == selected ? Colors.white : AppColors.gray600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchBox extends StatefulWidget {
  _SearchBox({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 34,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        // 화면 배경이 gray50과 같은 색이라 흰 면 + 테두리로 띄운다
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, size: 14, color: AppColors.gray500),
          SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _controller,
              style: AppTextStyles.body2.copyWith(fontSize: 13),
              cursorColor: AppColors.primary,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: '이름·직무 검색',
                hintStyle: AppTextStyles.body2.copyWith(
                  fontSize: 13,
                  color: AppColors.gray400,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 명단 카드
// ---------------------------------------------------------------------------

class _MemberCard extends StatefulWidget {
  _MemberCard({required this.member, required this.onTap});

  final _Member member;
  final VoidCallback onTap;

  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Pressable(
        onTap: widget.onTap,
        scale: 0.985,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 140),
          padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            // 커서를 올린 카드만 테두리에 색을 준다
            border: Border.all(
              color: _hovered ? AppColors.primary : AppColors.gray100,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(name: member.name, size: 46),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.title3,
                              ),
                            ),
                            if (member.isMe) ...[SizedBox(width: 6), _MeTag()],
                          ],
                        ),
                        SizedBox(height: 3),
                        Text(
                          '${member.role} · ${member.team}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              _StatusBadge(member: member),
              SizedBox(height: 14),
              Divider(height: 1, color: AppColors.divider),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      // 회원을 안 맡는 직무는 근속을 대신 보여준다
                      member.clients > 0
                          ? '담당 ${member.clients}명'
                          : '근속 ${member.career}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    member.phone,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 로그인한 사람 표시
class _MeTag extends StatelessWidget {
  _MeTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '나',
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// 상태 점 + 이름 (+ 상태 메시지)
class _StatusBadge extends StatelessWidget {
  _StatusBadge({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    final status = member.status;

    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: status.color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 7),
        Text(
          status.label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: status.color,
          ),
        ),
        if (member.note != null) ...[
          SizedBox(width: 8),
          Expanded(
            child: Text(
              member.note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 상세
// ---------------------------------------------------------------------------

/// 직원 한 명 상세 — 연락처와 이번 달 근태 요약
class _MemberDetail extends StatelessWidget {
  _MemberDetail({required this.member});

  final _Member member;

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    AppToast.show(context, '$label을 복사했어요');
  }

  @override
  Widget build(BuildContext context) {
    return PhoneDetailScaffold(
      title: member.name,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          32,
        ),
        children: [
          _ProfileCard(member: member),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: CupertinoIcons.chat_bubble_fill,
                  label: '사내톡',
                  primary: true,
                  onTap: () => AppToast.show(context, '사내톡은 준비 중이에요'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: CupertinoIcons.phone_fill,
                  label: '번호 복사',
                  onTap: () => _copy(context, '전화번호', member.phone),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: CupertinoIcons.mail_solid,
                  label: '메일 복사',
                  onTap: () => _copy(context, '이메일', member.email),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _InfoCard(
            title: '기본 정보',
            rows: [
              ('사번', member.code),
              ('소속', '${member.team} · ${member.role}'),
              ('입사일', _date(member.joined)),
              ('근속', member.career),
              ('전화번호', member.phone),
              ('이메일', member.email),
            ],
          ),
          SizedBox(height: 12),
          _MonthCard(member: member),
          if (member.clients > 0) ...[
            SizedBox(height: 12),
            _ClientCard(member: member),
          ],
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  _ProfileCard({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          Avatar(name: member.name, size: 62),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(member.name, style: AppTextStyles.title2),
                    if (member.isMe) ...[SizedBox(width: 6), _MeTag()],
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '${member.role} · ${member.team}',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 10),
                _StatusBadge(member: member),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// 가장 자주 쓰는 동작 하나만 파란 면으로
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = primary ? Colors.white : AppColors.textPrimary;

    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary ? AppColors.primary : AppColors.gray200,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  _InfoCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.label),
          SizedBox(height: 6),
          for (final (label, value) in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(label, style: AppTextStyles.caption),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w500,
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

/// 이번 달 근태 요약 — 근태·월차 화면의 요약 카드와 같은 눈금
class _MonthCard extends StatelessWidget {
  _MonthCard({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DateTime.now().month}월 근무',
                  style: AppTextStyles.label,
                ),
              ),
              Text('오늘까지', style: AppTextStyles.caption.copyWith(fontSize: 12)),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _stat('근무일', '${member.workedDays}일', AppColors.textPrimary),
              _divider(),
              _stat('총 근무', '${member.workedHours}시간', AppColors.primary),
              _divider(),
              _stat(
                '지각',
                '${member.lateCount}회',
                member.lateCount > 0
                    ? AppColors.warning
                    : AppColors.textPrimary,
              ),
              _divider(),
              _stat(
                '월차',
                '${_count(member.leaveUsed)}일',
                AppColors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: AppTextStyles.title3.copyWith(fontSize: 17, color: color),
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.gray100);
}

/// 담당 회원 — 트레이너·FC만
class _ClientCard extends StatelessWidget {
  _ClientCard({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    final trainer = member.sessions > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trainer ? '수업' : '상담', style: AppTextStyles.label),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${member.clients}명',
                      style: AppTextStyles.title3.copyWith(
                        fontSize: 19,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      trainer ? '담당 회원' : '이번 달 상담',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (trainer) ...[
                Container(width: 1, height: 32, color: AppColors.gray100),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${member.sessions}회',
                        style: AppTextStyles.title3.copyWith(fontSize: 19),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '이번 달 세션',
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// '2023년 3월 2일'
String _date(DateTime value) => '${value.year}년 ${value.month}월 ${value.day}일';

/// 소수점이 있을 때만 .5를 보여준다
String _count(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : value.toString();
