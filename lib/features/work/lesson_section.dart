import 'dart:ui';

import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/pressable.dart';

/// 수업 개수 탭 콘텐츠 (목업)
///
/// 수업은 회원의 싸인을 받아야 인정된다.
/// - 상단: 회원 등록 / 세션 싸인 받기 버튼
/// - 세션 기록: 받은 싸인 기록 (서명 미리보기·회차·시각)
class LessonSection extends StatefulWidget {
  LessonSection({super.key});

  @override
  State<LessonSection> createState() => _LessonSectionState();
}

/// 아바타 색 팔레트 — 새 회원 등록 시 순서대로 배정
const _palette = [
  Color(0xFF00A8B5),
  Color(0xFF7C5CFC),
  Color(0xFFE0447C),
  AppColors.success,
  AppColors.warning,
];

/// 등록된 회원 목록 (목업 초기값). 탭을 오가도 유지되도록 모듈 전역으로 둔다.
final _members = <_LessonMember>[
  _LessonMember(
    name: '박서연',
    color: _palette[0],
    total: 20,
    done: 12,
    price: 50000,
  ),
  _LessonMember(
    name: '최준영',
    color: _palette[1],
    total: 30,
    done: 0,
    price: 55000,
    isNew: true,
  ),
  _LessonMember(
    name: '한지우',
    color: _palette[2],
    total: 10,
    done: 9,
    price: 45000,
  ),
];

/// 다른 트레이너 담당 회원 (세션 싸인 받기의 전체 탭에서만 노출)
final _otherMembers = <_LessonMember>[
  _LessonMember(
    name: '정다은',
    color: _palette[3],
    total: 20,
    done: 3,
    price: 50000,
    isNew: true,
    owner: '이앨리스',
  ),
  _LessonMember(
    name: '윤태호',
    color: _palette[4],
    total: 30,
    done: 21,
    price: 60000,
    owner: '오민준',
  ),
];

/// 받은 싸인 내역 (표시할 때 최신순 정렬)
final _signs = <_LessonSign>[..._seedSigns()];

List<_LessonSign> _seedSigns() {
  final now = DateTime.now();
  // daysAgo일 전의 시각 — DateTime이 월 경계를 알아서 넘겨준다
  DateTime at(int daysAgo, int hour, int minute) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour, minute);
  const padSize = Size(300, 160);
  return [
    _LessonSign(
      member: '박서연',
      round: 12,
      total: 20,
      isNew: false,
      time: at(0, 9, 30),
      padSize: padSize,
      strokes: [
        [Offset(50, 100), Offset(80, 50), Offset(110, 105), Offset(140, 60)],
        [Offset(165, 55), Offset(195, 95), Offset(230, 58), Offset(255, 90)],
      ],
    ),
    _LessonSign(
      member: '한지우',
      round: 9,
      total: 10,
      isNew: false,
      time: at(0, 11, 0),
      padSize: padSize,
      strokes: [
        [Offset(60, 60), Offset(90, 100), Offset(120, 55), Offset(150, 95)],
        [Offset(175, 75), Offset(205, 75), Offset(240, 100)],
      ],
    ),
    _LessonSign(
      member: '한지우',
      round: 8,
      total: 10,
      isNew: false,
      time: at(1, 18, 20),
      padSize: padSize,
      strokes: [
        [Offset(55, 95), Offset(95, 55), Offset(135, 100), Offset(175, 60)],
        [Offset(200, 80), Offset(240, 80)],
      ],
    ),
    _LessonSign(
      member: '박서연',
      round: 11,
      total: 20,
      isNew: false,
      time: at(2, 20, 5),
      padSize: padSize,
      strokes: [
        [Offset(60, 70), Offset(100, 105), Offset(140, 55), Offset(180, 95)],
        [Offset(205, 60), Offset(235, 95), Offset(255, 70)],
      ],
    ),
  ];
}

/// 1,000 단위 콤마 표기
String _comma(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// '7.29 오전 9:30' 형태
String _formatStamp(DateTime time) {
  final period = time.hour < 12 ? '오전' : '오후';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.month}.${time.day} $period $hour:$minute';
}

/// 기록 줄을 누르면 서명을 크게 보여준다
void _showSignDetail(BuildContext context, _LessonSign sign) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '싸인 크게 보기',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 300,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: CustomPaint(
                  painter: _SignPainter(
                    strokes: sign.strokes,
                    sourceSize: sign.padSize,
                    color: AppColors.textPrimary,
                    strokeWidth: 2.4,
                  ),
                ),
              ),
              SizedBox(height: 14),
              Text(
                '${sign.member} · ${sign.round}/${sign.total}회차',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(_formatStamp(sign.time), style: AppTextStyles.caption),
            ],
          ),
        ),
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

class _LessonSectionState extends State<LessonSection> {
  /// 회원 등록 화면을 연다
  Future<void> _register() async {
    final added = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(builder: (_) => _RegisterScreen()),
    );
    if (added == true && mounted) setState(() {});
  }

  /// 회원을 골라 싸인을 받는다
  Future<void> _pickAndSign() async {
    await Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => _PickMemberScreen()),
    );
    // 싸인이 추가됐을 수 있으니 갱신한다
    if (mounted) setState(() {});
  }

  /// 세션 기록 전체 화면을 연다
  void _openHistory() {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => _SignHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 액션 버튼 두 개
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: CupertinoIcons.person_add,
                label: '회원 등록',
                onTap: _register,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: CupertinoIcons.signature,
                label: '세션 싸인 받기',
                highlighted: true,
                onTap: _pickAndSign,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        _buildRecordCard(),
      ],
    );
  }

  Widget _buildRecordCard() {
    final sorted = List.of(_signs)..sort((a, b) => b.time.compareTo(a.time));
    // 카드에는 최근 5건만 — 나머지는 전체 보기 화면에서
    final recent = sorted.take(5).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text('세션 기록', style: AppTextStyles.label),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_signs.length}',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                Pressable(
                  onTap: _openHistory,
                  scale: 0.92,
                  pressedColor: AppColors.gray100,
                  borderRadius: BorderRadius.circular(100),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '전체 보기',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 11,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          if (sorted.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 22),
              child: Text(
                '아직 받은 싸인이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.divider),
              _SignRow(
                sign: recent[i],
                onTap: () => _showSignDetail(context, recent[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// 상단 액션 버튼 — 강조(파랑)와 기본(흰색) 두 가지
class _ActionButton extends StatelessWidget {
  _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.primary : AppColors.textPrimary;

    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: highlighted ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.gray100,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            SizedBox(width: 7),
            Text(
              label,
              style: AppTextStyles.body2.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 신규/재등록 배지
class _MemberBadge extends StatelessWidget {
  _MemberBadge({required this.isNew});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: isNew ? AppColors.primaryLight : AppColors.gray100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isNew ? '신규' : '재등록',
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          color: isNew ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 등록된 회원 한 명
class _LessonMember {
  _LessonMember({
    required this.name,
    required this.color,
    required this.total,
    required this.price,
    this.done = 0,
    this.isNew = false,
    this.phone = '',
    this.referrer = '',
    this.owner = '',
  });

  final String name;
  final Color color;

  /// 등록한 총 수업 횟수 — 재등록하면 새 등록권으로 바뀐다
  int total;

  /// 세션(1회) 단가, 원 — 결제액을 회차로 나눈 값
  int price;

  /// 신규 회원 여부 (재등록하면 false로 바뀐다)
  bool isNew;

  /// 연락처·소개한 회원 (등록 폼 입력, 아직 화면 표시는 없음)
  final String phone;
  final String referrer;

  /// 담당 트레이너 이름 — 비어 있으면 내 담당
  final String owner;

  /// 싸인으로 확인된 진행 회차 — 싸인 한 번에 1회차씩 올라간다
  int done;
}

/// 싸인 기록 한 건
class _LessonSign {
  _LessonSign({
    required this.member,
    required this.round,
    required this.total,
    required this.isNew,
    required this.time,
    required this.strokes,
    required this.padSize,
  });

  final String member;

  /// 몇 회차 수업인지 / 총 몇 회 등록인지
  final int round;
  final int total;
  final bool isNew;
  final DateTime time;

  /// 서명 획 좌표 (패드 좌표계)
  final List<List<Offset>> strokes;

  /// 서명 당시 패드 크기 — 미리보기 비율 맞춤에 사용
  final Size padSize;
}

/// 세션 기록 한 줄 — 서명 미리보기, 이름·배지, 회차·시각, +1
class _SignRow extends StatelessWidget {
  _SignRow({required this.sign, required this.onTap});

  final _LessonSign sign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      pressedColor: AppColors.gray50,
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          // 서명 미리보기
          Container(
            width: 64,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gray100),
            ),
            child: CustomPaint(
              painter: _SignPainter(
                strokes: sign.strokes,
                sourceSize: sign.padSize,
                color: AppColors.textPrimary,
                strokeWidth: 1.4,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      sign.member,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6),
                    _MemberBadge(isNew: sign.isNew),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  '${sign.round}/${sign.total}회차 · ${_formatStamp(sign.time)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '+1',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 6),
          Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: AppColors.gray300,
          ),
        ],
      ),
    );
  }
}

/// 세션 기록 전체 화면 — 옆에서 슬라이드되어 열리고 날짜별로 묶어 보여준다
class _SignHistoryScreen extends StatelessWidget {
  /// 오늘/어제/그 외 날짜 라벨
  String _dayLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${time.month}.${time.day}';
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List.of(_signs)..sort((a, b) => b.time.compareTo(a.time));

    // 날짜가 바뀌는 지점마다 그룹 헤더를 끼워 넣는다
    final children = <Widget>[];
    String? label;
    for (final sign in sorted) {
      final dayLabel = _dayLabel(sign.time);
      if (dayLabel != label) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, label == null ? 4 : 22, 4, 4),
            child: Text(
              dayLabel,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        label = dayLabel;
      } else {
        children.add(Divider(height: 1, color: AppColors.divider));
      }
      children.add(
        _SignRow(sign: sign, onTap: () => _showSignDetail(context, sign)),
      );
    }

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
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('받은 싸인 기록', style: AppTextStyles.caption),
                      ),
                      Text(
                        '총 ${_signs.length}건',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                if (sorted.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                    child: Text(
                      '아직 받은 싸인이 없어요',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        8,
                        20,
                        MediaQuery.paddingOf(context).bottom + 24,
                      ),
                      children: children,
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
                  child: Text('세션 기록', style: AppTextStyles.title3),
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

/// 회원 등록 화면 — 신규/재등록을 전환하며 회원 정보와 등록권을 입력한다
class _RegisterScreen extends StatefulWidget {
  @override
  State<_RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<_RegisterScreen> {
  /// true면 재등록 모드
  bool _renew = false;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _referrer = TextEditingController();
  final _rounds = TextEditingController();
  final _payment = TextEditingController();
  final _search = TextEditingController();

  /// 재등록 모드에서 선택된 기존 회원
  _LessonMember? _selected;

  @override
  void initState() {
    super.initState();
    // 입력에 따라 등록 버튼·회당 단가·검색 결과가 실시간 갱신되도록 한다
    for (final controller in [_name, _rounds, _payment, _search]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _referrer,
      _rounds,
      _payment,
      _search,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _roundCount => int.tryParse(_rounds.text.trim()) ?? 0;
  int get _paymentWon => int.tryParse(_payment.text.trim()) ?? 0;

  /// 회당 단가 — 결제액 ÷ 회차
  int get _unitPrice => _roundCount > 0 && _paymentWon > 0
      ? (_paymentWon / _roundCount).round()
      : 0;

  /// 검색어로 걸러진 기존 회원 목록
  List<_LessonMember> get _filtered {
    final query = _search.text.trim();
    if (query.isEmpty) return _members;
    return _members.where((m) => m.name.contains(query)).toList();
  }

  bool get _complete =>
      (_renew ? _selected != null : _name.text.trim().isNotEmpty) &&
      _roundCount > 0 &&
      _paymentWon > 0;

  void _submit() {
    if (!_complete) {
      AppToast.show(
        context,
        _renew ? '재등록할 회원과 등록권 정보를 입력해주세요' : '성함과 등록권 정보를 입력해주세요',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    if (_renew) {
      // 기존 회원에게 새 등록권을 부여한다
      final member = _selected!;
      member.total = _roundCount;
      member.price = _unitPrice;
      member.done = 0;
      member.isNew = false;
      AppToast.show(context, '${member.name}님이 재등록되었습니다');
    } else {
      final name = _name.text.trim();
      _members.add(
        _LessonMember(
          name: name,
          color: _palette[_members.length % _palette.length],
          total: _roundCount,
          price: _unitPrice,
          isNew: true,
          phone: _phone.text.trim(),
          referrer: _referrer.text.trim(),
        ),
      );
      AppToast.show(context, '$name님이 등록되었습니다');
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 상단 고정 타이틀 영역만큼 비워둔다
                SizedBox(height: 56),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      MediaQuery.paddingOf(context).bottom + 96,
                    ),
                    children: [
                      _ModeSwitch(
                        left: '신규 회원',
                        right: '재등록',
                        value: _renew,
                        onChanged: (v) => setState(() => _renew = v),
                      ),
                      SizedBox(height: 24),
                      if (_renew) ...[
                        // 재등록: 기존 회원을 검색해 선택한다
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('재등록할 회원', style: AppTextStyles.label),
                        ),
                        SizedBox(height: 8),
                        _FormField(controller: _search, hint: '회원 이름 검색'),
                        SizedBox(height: 8),
                        // 신규 탭의 입력 3칸 높이에 맞춘 스크롤 영역 —
                        // 회원이 많아져도 등록권 위치가 밀리지 않는다
                        SizedBox(
                          height: 108,
                          child: _filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    '검색 결과가 없어요',
                                    style: AppTextStyles.body2.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ListView(
                                    padding: EdgeInsets.zero,
                                    children: [
                                      for (
                                        var i = 0;
                                        i < _filtered.length;
                                        i++
                                      ) ...[
                                        if (i > 0) SizedBox(height: 8),
                                        _RenewPickRow(
                                          member: _filtered[i],
                                          selected: _selected == _filtered[i],
                                          onTap: () => setState(
                                            () => _selected = _filtered[i],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                        ),
                        SizedBox(height: 24),
                      ] else ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('회원 정보', style: AppTextStyles.label),
                        ),
                        SizedBox(height: 8),
                        _FormField(controller: _name, hint: '성함'),
                        SizedBox(height: 8),
                        _FormField(
                          controller: _phone,
                          hint: '연락처 (010-0000-0000)',
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 8),
                        _FormField(controller: _referrer, hint: '소개한 회원 (선택)'),
                        SizedBox(height: 24),
                      ],
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('등록권', style: AppTextStyles.label),
                      ),
                      SizedBox(height: 8),
                      _FormField(
                        controller: _rounds,
                        hint: '회차 (예: 30)',
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 8),
                      _FormField(
                        controller: _payment,
                        hint: '결제액 (원)',
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 14),
                      // 결제액 ÷ 회차로 자동 계산되는 단가
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '회당 단가',
                                style: AppTextStyles.body2.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              _unitPrice > 0 ? '${_comma(_unitPrice)}원' : '—',
                              style: AppTextStyles.body2.copyWith(
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
                  child: Text('회원 등록', style: AppTextStyles.title3),
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
          // 하단 고정: 네이티브 리퀴드 글래스 등록 버튼
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: CNButton(
                        // 테마 전환 시 설정 유실 버그 회피용 재생성 키
                        key: ValueKey('register-${AppColors.isDark}'),
                        label: _renew ? '재등록' : '신규 회원 등록',
                        // 필수 입력이 채워지기 전에는 글래스, 채워지면 파란
                        // 프로미넌트 글래스. 비활성화하면 iOS가 글래스 재질을
                        // 빼버려서 항상 활성으로 두고, 미완성 시 동작은
                        // _submit에서 무시한다.
                        style: _complete
                            ? CNButtonStyle.prominentGlass
                            : CNButtonStyle.glass,
                        tint: AppColors.primary,
                        height: 56,
                        onPressed: _submit,
                      ),
                    ),
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

/// 재등록할 회원 선택 줄 — 선택되면 파란 배경과 체크로 표시
class _RenewPickRow extends StatelessWidget {
  _RenewPickRow({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final _LessonMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.25)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: member.color,
                shape: BoxShape.circle,
              ),
              child: Text(
                member.name.characters.first,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                member.name,
                style: AppTextStyles.body2.copyWith(
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                size: 18,
                color: AppColors.primary,
              )
            else
              Text(
                '내 담당',
                style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
              ),
          ],
        ),
      ),
    );
  }
}

/// 신규 회원 / 재등록 전환 세그먼트
class _ModeSwitch extends StatelessWidget {
  _ModeSwitch({
    required this.left,
    required this.right,
    required this.value,
    required this.onChanged,
  });

  final String left;
  final String right;

  /// true면 오른쪽이 선택된 상태
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: left,
              selected: !value,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _Segment(
              label: right,
              selected: value,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.gray100 : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.body2.copyWith(
              fontSize: 14,
              color: selected ? AppColors.textPrimary : AppColors.gray500,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 회색 입력 칸
class _FormField extends StatelessWidget {
  _FormField({required this.controller, required this.hint, this.keyboardType});

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: AppTextStyles.body1,
        cursorColor: AppColors.primary,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.body1.copyWith(color: AppColors.gray400),
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

/// 싸인 받을 회원 선택 화면
class _PickMemberScreen extends StatefulWidget {
  @override
  State<_PickMemberScreen> createState() => _PickMemberScreenState();
}

class _PickMemberScreenState extends State<_PickMemberScreen> {
  /// true면 전체(다른 담당 포함) 목록
  bool _all = false;

  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_LessonMember> get _filtered {
    final base = _all ? [..._members, ..._otherMembers] : _members;
    final query = _search.text.trim();
    if (query.isEmpty) return base;
    return base.where((m) => m.name.contains(query)).toList();
  }

  /// 회원을 누르면 바로 서명 화면으로 이동한다
  Future<void> _open(_LessonMember member) async {
    final done = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(builder: (_) => _SignScreen(member: member)),
    );
    // 싸인을 받았으면 선택 화면도 닫고 업무 탭으로 돌아간다
    if (done == true && mounted) Navigator.pop(context);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 상단 고정 타이틀 영역만큼 비워둔다
                SizedBox(height: 56),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      MediaQuery.paddingOf(context).bottom + 96,
                    ),
                    children: [
                      _ModeSwitch(
                        left: '내 담당 (${_members.length})',
                        right: '전체',
                        value: _all,
                        onChanged: (v) => setState(() => _all = v),
                      ),
                      SizedBox(height: 12),
                      if (list.isEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(4, 10, 4, 10),
                          child: Text(
                            '검색 결과가 없어요',
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      else
                        for (final member in list) ...[
                          _PickRow(member: member, onTap: () => _open(member)),
                          SizedBox(height: 8),
                        ],
                    ],
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
                  child: Text('세션 싸인 받기', style: AppTextStyles.title3),
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
          // 하단 고정: 플로팅 글래스 검색 바 (키보드와 함께 상승)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1F101828),
                        blurRadius: 32,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                      child: Container(
                        height: 52,
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(28),
                          // 네이티브 글래스의 림처럼 보이는 헤어라인
                          border: Border.all(color: AppColors.gray100),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.search,
                              size: 20,
                              color: AppColors.gray500,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _search,
                                style: AppTextStyles.body2,
                                cursorColor: AppColors.primary,
                                decoration: InputDecoration(
                                  hintText: '회원 이름 검색',
                                  hintStyle: AppTextStyles.body2.copyWith(
                                    color: AppColors.gray400,
                                  ),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 싸인 받을 회원 한 줄 — 누르면 바로 서명 화면으로 이동
class _PickRow extends StatelessWidget {
  _PickRow({required this.member, required this.onTap});

  final _LessonMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final remain = member.total - member.done;
    final ownerLabel = member.owner.isEmpty ? '내 담당' : '${member.owner} 담당';

    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: member.color,
                shape: BoxShape.circle,
              ),
              child: Text(
                member.name.characters.first,
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
                  Row(
                    children: [
                      Text(
                        member.name,
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      _MemberBadge(isNew: member.isNew),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${member.done}/${member.total}회차 사용 · $ownerLabel',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            // 남은 회차 배지
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$remain회 남음',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: AppColors.gray300,
            ),
          ],
        ),
      ),
    );
  }
}

/// 싸인 받기 화면 — 회원이 손가락으로 서명하고 완료를 누르면 기록된다
class _SignScreen extends StatefulWidget {
  _SignScreen({required this.member});

  final _LessonMember member;

  @override
  State<_SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<_SignScreen> {
  final List<List<Offset>> _strokes = [];

  /// 완료 시 기록에 남길 패드 크기
  Size _padSize = Size.zero;

  bool get _signed => _strokes.any((stroke) => stroke.length > 1);

  void _clear() => setState(_strokes.clear);

  void _complete() {
    if (!_signed) {
      AppToast.show(context, '먼저 싸인을 받아주세요');
      return;
    }
    final member = widget.member;
    member.done += 1;
    _signs.add(
      _LessonSign(
        member: member.name,
        round: member.done,
        total: member.total,
        isNew: member.isNew,
        time: DateTime.now(),
        strokes: [for (final stroke in _strokes) List.of(stroke)],
        padSize: _padSize,
      ),
    );
    AppToast.show(context, '${member.name}님 ${member.done}회차 수업이 기록되었습니다');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

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
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${member.done + 1}/${member.total}회차 수업 확인',
                          style: AppTextStyles.caption,
                        ),
                      ),
                      // 다시 쓰기
                      Pressable(
                        onTap: _clear,
                        scale: 0.93,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray50,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.arrow_counterclockwise,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 5),
                              Text(
                                '다시 쓰기',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                // 서명 패드 — 남은 화면을 채운다
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      MediaQuery.paddingOf(context).bottom + 96,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _padSize = constraints.biggest;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: GestureDetector(
                            onPanStart: (d) =>
                                setState(() => _strokes.add([d.localPosition])),
                            onPanUpdate: (d) => setState(
                              () => _strokes.last.add(d.localPosition),
                            ),
                            child: Container(
                              color: AppColors.gray50,
                              child: Stack(
                                children: [
                                  if (!_signed)
                                    Center(
                                      child: Text(
                                        '여기에 싸인해주세요',
                                        style: AppTextStyles.body1.copyWith(
                                          color: AppColors.gray400,
                                        ),
                                      ),
                                    ),
                                  CustomPaint(
                                    size: Size.infinite,
                                    painter: _SignPainter(
                                      strokes: _strokes,
                                      color: AppColors.textPrimary,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
                  child: Text('${member.name} 싸인', style: AppTextStyles.title3),
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
          // 하단 고정: 네이티브 리퀴드 글래스 완료 버튼
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: CNButton(
                        // 테마 전환 시 설정 유실 버그 회피용 재생성 키
                        key: ValueKey('sign-done-${AppColors.isDark}'),
                        label: '싸인 완료',
                        // 서명 전에는 글래스, 서명하면 파란 프로미넌트 글래스.
                        // 비활성화하면 iOS가 글래스 재질을 빼버려서 항상 활성으로
                        // 두고, 미서명 시 동작은 _complete에서 무시한다.
                        style: _signed
                            ? CNButtonStyle.prominentGlass
                            : CNButtonStyle.glass,
                        tint: AppColors.primary,
                        height: 56,
                        onPressed: _complete,
                      ),
                    ),
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

/// 서명 획을 그리는 페인터 — sourceSize가 있으면 미리보기용으로 비율 축소
class _SignPainter extends CustomPainter {
  _SignPainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
    this.sourceSize,
  });

  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;
  final Size? sourceSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final source = sourceSize;
    if (source != null && source.width > 0 && source.height > 0) {
      final scale = (size.width / source.width) < (size.height / source.height)
          ? size.width / source.width
          : size.height / source.height;
      // 축소 후 가운데 정렬
      canvas.translate(
        (size.width - source.width * scale) / 2,
        (size.height - source.height * scale) / 2,
      );
      canvas.scale(scale);
    }

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignPainter oldDelegate) => true;
}
