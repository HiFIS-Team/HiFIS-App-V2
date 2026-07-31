import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/lesson_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/glass_bottom_button.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../core/widgets/mode_switch.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/see_all_button.dart';

/// 수업 개수 탭 콘텐츠
///
/// 수업은 회원의 싸인을 받아야 인정된다.
/// - 상단: 회원 등록 / 세션 싸인 받기 버튼
/// - 세션 기록: 받은 싸인 기록 (서명 미리보기·회차·시각)
class LessonSection extends StatefulWidget {
  LessonSection({super.key});

  @override
  State<LessonSection> createState() => _LessonSectionState();
}

// ---------------------------------------------------------------------------
// 서버 데이터
// ---------------------------------------------------------------------------

/// 이 화면이 쓰는 서버 데이터 한 벌
///
/// 회원·등록권·싸인을 따로 받아 앱에서 id 로 맞춘다. 서버 싸인 응답에
/// 회원 이름도 총 회차도 신규/재등록도 없어서다 (backend-gap.md 24번).
///
/// 화면을 열 때마다 새로 받는다 — 서명 URL 이 7일이면 만료돼서
/// 오래 들고 있으면 이미지가 403 으로 떨어진다.
class _LessonStore {
  _LessonStore._();

  static final _LessonStore instance = _LessonStore._();

  List<Member> members = const [];
  List<Registration> registrations = const [];
  List<SessionSign> signs = const [];

  Future<void> load() async {
    // 셋 다 서로를 안 기다려도 되니 같이 띄운다
    final memberRequest = MemberApi.list();
    final registrationRequest = RegistrationApi.list();
    final signRequest = SessionSignApi.list(trainerId: currentUser?.id);

    members = await memberRequest;
    registrations = await registrationRequest;
    signs = await signRequest;
  }

  Member? memberOf(String id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  Registration? registrationOf(String id) {
    for (final registration in registrations) {
      if (registration.id == id) return registration;
    }
    return null;
  }

  /// 회원이 지금 쓰는 등록권
  ///
  /// 회차가 남은 것 중 가장 최근 것. 다 썼으면 마지막 등록권을 준다 —
  /// "20/20회차 사용"까지는 보여줘야 재등록하러 갈 수 있다.
  Registration? currentRegistrationOf(String memberId) {
    Registration? fallback;
    for (final registration in registrations) {
      if (registration.memberId != memberId) continue;
      if (!registration.exhausted) {
        if (fallback == null ||
            fallback.exhausted ||
            registration.purchasedAt.isAfter(fallback.purchasedAt)) {
          fallback = registration;
        }
      } else if (fallback == null ||
          (fallback.exhausted &&
              registration.purchasedAt.isAfter(fallback.purchasedAt))) {
        fallback = registration;
      }
    }
    return fallback;
  }

  _LessonMember _wrap(Member member) => _LessonMember(
    source: member,
    registration: currentRegistrationOf(member.id),
  );

  /// 내가 담당하는 회원
  List<_LessonMember> get myMembers => [
    for (final member in members)
      if (member.ownerTrainerId == currentUser?.id) _wrap(member),
  ];

  /// 지점 전체 회원 (대타로 싸인 받을 때)
  List<_LessonMember> get allMembers => [for (final m in members) _wrap(m)];

  /// 내가 받은 싸인 — 회원·등록권을 붙여서
  List<_LessonSign> get mySigns {
    final rows = [
      for (final sign in signs)
        _LessonSign(
          source: sign,
          memberName: memberOf(sign.memberId)?.name ?? '알 수 없음',
          registration: registrationOf(sign.registrationId),
        ),
    ];
    return rows..sort((a, b) => b.time.compareTo(a.time));
  }
}

/// 화면이 다루는 회원 한 명 — 서버 회원에 지금 쓰는 등록권을 붙인 것
class _LessonMember {
  _LessonMember({required this.source, required this.registration});

  final Member source;

  /// 지금 쓰는 등록권 — 등록권이 하나도 없는 회원이면 null
  final Registration? registration;

  String get id => source.id;
  String get name => source.name;
  Color get color => avatarColorFor(source.name);

  int get total => registration?.totalSessions ?? 0;
  int get done => registration?.usedSessions ?? 0;
  int get remaining => registration?.remaining ?? 0;
  int get price => registration?.sessionUnitPrice ?? 0;

  bool get isNew => registration?.type == RegistrationType.newMember;

  /// 싸인을 더 받을 수 있는가 — 등록권이 없거나 회차를 다 쓰면 못 받는다
  bool get canSign => registration != null && !registration!.exhausted;

  bool get mine => source.ownerTrainerId == currentUser?.id;

  /// 담당 트레이너 이름 — 내 담당이면 빈 문자열
  String get owner {
    if (mine) return '';
    return StaffDirectory.instance.byId(source.ownerTrainerId)?.name ?? '';
  }
}

/// 세션 기록 한 줄 — 싸인에 회원 이름과 등록권을 붙여 놓은 것
class _LessonSign {
  _LessonSign({
    required this.source,
    required this.memberName,
    required this.registration,
  });

  final SessionSign source;
  final String memberName;

  /// 어느 등록권의 몇 회차인지 — 목록에서 빠졌으면 null
  final Registration? registration;

  int get round => source.sessionNo;
  int get total => registration?.totalSessions ?? 0;
  bool get isNew => registration?.type == RegistrationType.newMember;
  DateTime get time => source.signedAt;

  /// 서명 이미지 주소
  String get imageUrl => source.signatureFullUrl;
}

/// 서명 획을 PNG base64 로 만든다 — 서버는 좌표가 아니라 이미지를 받는다
///
/// 그림으로 저장해야 나중에 그리는 코드가 바뀌어도 회원이 실제로 쓴
/// 싸인이 그대로 남는다. 좌표만 두면 증거로 쓸 수 없다.
Future<String> _encodeSignature(List<List<Offset>> strokes, Size size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // 배경을 깔아 준다 — 투명 PNG 는 어두운 배경에서 획이 안 보인다
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = Colors.white,
  );
  _SignPainter(
    strokes: strokes,
    color: Colors.black,
    strokeWidth: 3,
  ).paint(canvas, size);

  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return base64Encode(data!.buffer.asUint8List());
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

/// 저장된 서명 이미지 — 실패해도 화면이 안 죽게 자리만 남긴다
class _SignImage extends StatelessWidget {
  _SignImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: BoxFit.contain,
    // 서명 URL 은 7일이면 만료된다 — 그때는 목록을 다시 받아야 새 주소가 온다
    errorBuilder: (context, error, stack) => Center(
      child: Icon(CupertinoIcons.signature, size: 16, color: AppColors.gray300),
    ),
  );
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
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _SignImage(url: sign.imageUrl),
              ),
              SizedBox(height: 14),
              Text(
                sign.total > 0
                    ? '${sign.memberName} · ${sign.round}/${sign.total}회차'
                    : '${sign.memberName} · ${sign.round}회차',
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _LessonStore.instance.load();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 회원 등록 화면을 연다 — 폰은 밀려 들어오고 PC는 모달로 뜬다
  Future<void> _register() async {
    final added = await showFullPage<bool>(context, (_) => _RegisterScreen());
    if (added == true && mounted) await _load();
  }

  /// 회원을 골라 싸인을 받는다
  Future<void> _pickAndSign() async {
    final signed = await showFullPage<bool>(
      context,
      (_) => _PickMemberScreen(),
    );
    if (signed == true && mounted) await _load();
  }

  /// 세션 기록 전체 화면을 연다
  void _openHistory() {
    showFullPage<void>(context, (_) => _SignHistoryScreen());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    return Column(
      children: [
        _SessionGoalCard(),
        SizedBox(height: 16),
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
    final sorted = _LessonStore.instance.mySigns;
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
                    '${sorted.length}',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                SeeAllButton(onTap: _openHistory),
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

/// 이번 달 세션 목표
///
/// 서버에 목표치 개념이 없어서 고정값이다 (backend-gap.md 4번).
/// 누가 정하는지(대표 일괄 / 점장이 지점별)가 정해지면 서버에서 받아 온다.
const _sessionGoal = 50;

/// 이번 달 목표 진행 — 세션 수와 담당 회원을 한자리에서 보여준다
///
/// 숫자만 있으면 지금 잘 가고 있는지 알 수 없어서 목표 대비 막대를 같이 둔다.
class _SessionGoalCard extends StatelessWidget {
  _SessionGoalCard();

  @override
  Widget build(BuildContext context) {
    final store = _LessonStore.instance;
    final now = DateTime.now();
    final count = store.signs
        .where(
          (s) => s.signedAt.year == now.year && s.signedAt.month == now.month,
        )
        .length;
    final left = _sessionGoal - count;
    final reached = left <= 0;
    final color = reached ? AppColors.success : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('${now.month}월 세션', style: AppTextStyles.label),
              ),
              Text(
                '$count',
                style: AppTextStyles.title2.copyWith(color: color),
              ),
              Text(
                ' / $_sessionGoal회',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          ProgressBar(ratio: count / _sessionGoal, color: color),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(
                reached
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.flag_fill,
                size: 13,
                color: color,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  reached ? '이번 달 목표를 채웠어요' : '목표까지 $left회 남았어요',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Text(
                '담당 회원 ${store.myMembers.length}명',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
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

/// 세션 기록 한 줄 — 서명 미리보기, 이름·배지, 회차·시각, +1
class _SignRow extends StatelessWidget {
  _SignRow({required this.sign, required this.onTap});

  final _LessonSign sign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final round = sign.total > 0
        ? '${sign.round}/${sign.total}회차'
        : '${sign.round}회차';

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
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gray100),
            ),
            child: _SignImage(url: sign.imageUrl),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      sign.memberName,
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
                  '$round · ${_formatStamp(sign.time)}',
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
class _SignHistoryScreen extends StatefulWidget {
  @override
  State<_SignHistoryScreen> createState() => _SignHistoryScreenState();
}

class _SignHistoryScreenState extends State<_SignHistoryScreen> {
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
    final all = _LessonStore.instance.mySigns;
    final query = _search.text.trim();
    final sorted = all
        .where((s) => query.isEmpty || s.memberName.contains(query))
        .toList();

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
                if (sorted.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                    child: Text(
                      all.isEmpty ? '아직 받은 싸인이 없어요' : '검색 결과가 없어요',
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
                        // 하단 글래스 검색 바에 가리지 않도록 여유를 둔다
                        MediaQuery.paddingOf(context).bottom + 96,
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
          // 하단 고정: 플로팅 글래스 검색 바 (키보드와 함께 상승)
          GlassSearchBar(controller: _search, hint: '회원 이름 검색'),
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
  final _rounds = TextEditingController();
  final _payment = TextEditingController();
  final _search = TextEditingController();

  /// 재등록 모드에서 선택된 기존 회원
  _LessonMember? _selected;

  /// 소개한 회원 — 서버가 이름이 아니라 회원 id 를 요구해서 골라 받는다
  ///
  /// 소개로 온 회원은 급여 인센티브가 워크인(40%)이 아니라 재등록과 같은
  /// 요율(50%)로 잡힌다. 비워 두면 트레이너 몫이 줄어든다.
  Member? _referrer;

  bool _saving = false;

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
    for (final controller in [_name, _phone, _rounds, _payment, _search]) {
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

  /// 검색어로 걸러진 내 담당 회원 목록
  List<_LessonMember> get _filtered {
    final base = _LessonStore.instance.myMembers;
    final query = _search.text.trim();
    if (query.isEmpty) return base;
    return base.where((m) => m.name.contains(query)).toList();
  }

  bool get _complete =>
      (_renew
          ? _selected != null
          : _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty) &&
      _roundCount > 0 &&
      _paymentWon > 0;

  Future<void> _pickReferrer() async {
    final picked = await showFullPage<Member>(
      context,
      (_) => _ReferrerPickScreen(selected: _referrer),
    );
    if (picked != null && mounted) setState(() => _referrer = picked);
  }

  Future<void> _submit() async {
    if (!_complete) {
      AppToast.show(
        context,
        _renew ? '재등록할 회원과 등록권 정보를 입력해주세요' : '성함·연락처와 등록권 정보를 입력해주세요',
      );
      return;
    }
    if (_saving) return;

    final me = currentUser;
    if (me == null) {
      AppToast.show(context, '로그인 정보를 확인할 수 없어요');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      if (_renew) {
        // 기존 회원에게 새 등록권을 하나 더 발급한다
        final member = _selected!;
        await RegistrationApi.create(
          memberId: member.id,
          trainerId: me.id,
          type: RegistrationType.renewal,
          totalSessions: _roundCount,
          pricePaid: _paymentWon,
          sessionUnitPrice: _unitPrice,
        );
        if (!mounted) return;
        AppToast.show(context, '${member.name}님이 재등록되었습니다');
      } else {
        // 서버는 회원과 등록권이 따로다 — 회원을 만들고 등록권을 붙인다
        final name = _name.text.trim();
        final member = await MemberApi.create(
          name: name,
          phone: _phone.text.trim(),
          branchId: me.branchId,
          ownerTrainerId: me.id,
          referrerMemberId: _referrer?.id,
        );
        try {
          await RegistrationApi.create(
            memberId: member.id,
            trainerId: me.id,
            type: RegistrationType.newMember,
            totalSessions: _roundCount,
            pricePaid: _paymentWon,
            sessionUnitPrice: _unitPrice,
          );
        } catch (error) {
          // 회원은 만들어졌는데 등록권이 실패한 상태 — 그냥 실패로 덮으면
          // 다시 등록할 때 같은 회원이 두 명 생긴다
          if (!mounted) return;
          setState(() => _saving = false);
          AppToast.show(
            context,
            '$name님은 등록됐지만 등록권 발급에 실패했어요. 재등록으로 다시 시도해 주세요',
          );
          Navigator.pop(context, true);
          return;
        }
        if (!mounted) return;
        AppToast.show(context, '$name님이 등록되었습니다');
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, messageOf(error));
    }
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
                      ModeSwitch(
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
                        // 신규 탭의 입력 3칸을 투명한 틀로 깔아 전체 높이를
                        // 픽셀 단위로 똑같이 맞춘다 — 등록권 위치가 두 탭에서
                        // 완전히 같아지고, 회원 목록은 남는 공간에서 스크롤된다.
                        Stack(
                          children: [
                            IgnorePointer(
                              child: Opacity(
                                opacity: 0,
                                child: Column(
                                  children: [
                                    _FormField(controller: _name, hint: ''),
                                    SizedBox(height: 8),
                                    _FormField(controller: _phone, hint: ''),
                                    SizedBox(height: 8),
                                    _PickerField(label: '', value: null),
                                  ],
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Column(
                                children: [
                                  _FormField(
                                    controller: _search,
                                    hint: '회원 이름 검색',
                                  ),
                                  SizedBox(height: 8),
                                  Expanded(
                                    child: _filtered.isEmpty
                                        ? Center(
                                            child: Text(
                                              _LessonStore
                                                      .instance
                                                      .myMembers
                                                      .isEmpty
                                                  ? '담당 회원이 없어요'
                                                  : '검색 결과가 없어요',
                                              style: AppTextStyles.body2
                                                  .copyWith(
                                                    color:
                                                        AppColors.textTertiary,
                                                  ),
                                            ),
                                          )
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: ListView(
                                              padding: EdgeInsets.zero,
                                              children: [
                                                for (
                                                  var i = 0;
                                                  i < _filtered.length;
                                                  i++
                                                ) ...[
                                                  if (i > 0)
                                                    SizedBox(height: 8),
                                                  _RenewPickRow(
                                                    name: _filtered[i].name,
                                                    color: _filtered[i].color,
                                                    trailing: '내 담당',
                                                    selected:
                                                        _selected?.id ==
                                                        _filtered[i].id,
                                                    onTap: () => setState(
                                                      () => _selected =
                                                          _filtered[i],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                        // 소개한 회원은 이름이 아니라 등록된 회원을 골라야 한다
                        _PickerField(
                          label: '소개한 회원 (선택)',
                          value: _referrer?.name,
                          onTap: _pickReferrer,
                          onClear: _referrer == null
                              ? null
                              : () => setState(() => _referrer = null),
                        ),
                        if (_referrer != null) ...[
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.info_circle,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    '소개로 온 회원이라 인센티브가 재등록과 같은 요율로 잡혀요',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
            child: BottomActionBar(
              children: [
                Expanded(
                  child: BottomActionButton(
                    id: 'register',
                    label: _saving
                        ? '등록 중...'
                        : _renew
                        ? '재등록'
                        : '신규 회원 등록',
                    // 필수 입력이 채워져야 채워진 상태가 되고,
                    // 미완성 시 동작은 _submit에서 무시한다
                    filled: _complete && !_saving,
                    onPressed: _submit,
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

/// 소개한 회원 고르기 — 지점 전체 회원에서 찾는다
///
/// 소개자가 우리 센터 회원이 아니면 고를 수 없다. 서버가 실제 회원인지
/// 검증하기 때문에 이름만 적어 보낼 수 없다.
class _ReferrerPickScreen extends StatefulWidget {
  _ReferrerPickScreen({this.selected});

  final Member? selected;

  @override
  State<_ReferrerPickScreen> createState() => _ReferrerPickScreenState();
}

class _ReferrerPickScreenState extends State<_ReferrerPickScreen> {
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

  List<Member> get _filtered {
    final base = _LessonStore.instance.members;
    final query = _search.text.trim();
    if (query.isEmpty) return base;
    return base.where((m) => m.name.contains(query)).toList();
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
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Text(
                    '이 회원을 데려온 기존 회원을 골라주세요',
                    style: AppTextStyles.caption,
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Text(
                            '검색 결과가 없어요',
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            12,
                            20,
                            MediaQuery.paddingOf(context).bottom + 96,
                          ),
                          children: [
                            for (var i = 0; i < list.length; i++) ...[
                              if (i > 0) SizedBox(height: 8),
                              _RenewPickRow(
                                name: list[i].name,
                                color: avatarColorFor(list[i].name),
                                trailing: list[i].phone,
                                selected: widget.selected?.id == list[i].id,
                                onTap: () => Navigator.pop(context, list[i]),
                              ),
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
                  child: Text('소개한 회원', style: AppTextStyles.title3),
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
          GlassSearchBar(controller: _search, hint: '회원 이름 검색'),
        ],
      ),
    );
  }
}

/// 회원 선택 줄 — 선택되면 파란 배경과 체크로 표시
class _RenewPickRow extends StatelessWidget {
  _RenewPickRow({
    required this.name,
    required this.color,
    required this.trailing,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final String trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      // 배경은 애니메이션 없이 즉시 — 페이드가 있으면 직전에 고른 회원이
      // 서서히 사라지며 둘 다 선택된 것처럼 보인다
      child: Container(
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
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                name.characters.first,
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
                name,
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
                trailing,
                style: AppTextStyles.caption.copyWith(color: AppColors.gray400),
              ),
          ],
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

/// 눌러서 고르는 칸 — 입력 칸과 같은 모양이라 폼에서 줄이 맞는다
class _PickerField extends StatelessWidget {
  _PickerField({
    required this.label,
    required this.value,
    this.onTap,
    this.onClear,
  });

  final String label;

  /// 고른 값 — 없으면 [label]이 회색으로 뜬다
  final String? value;

  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final picked = value != null;

    return Pressable(
      onTap: onTap ?? () {},
      scale: 0.99,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                picked ? value! : label,
                style: AppTextStyles.body1.copyWith(
                  color: picked ? AppColors.textPrimary : AppColors.gray400,
                ),
              ),
            ),
            if (picked && onClear != null)
              Pressable(
                onTap: onClear!,
                scale: 0.9,
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 17,
                  color: AppColors.gray300,
                ),
              )
            else
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
    final store = _LessonStore.instance;
    final base = _all ? store.allMembers : store.myMembers;
    final query = _search.text.trim();
    if (query.isEmpty) return base;
    return base.where((m) => m.name.contains(query)).toList();
  }

  /// 회원을 누르면 바로 서명 화면으로 이동한다
  ///
  /// 선택 화면이 PC에서 모달이라 서명도 모달로 겹쳐 띄운다.
  /// (여기서 push를 쓰면 모달 밖 루트로 나가 창 전체를 덮는다)
  Future<void> _open(_LessonMember member) async {
    if (!member.canSign) {
      AppToast.show(
        context,
        member.registration == null
            ? '${member.name}님은 등록권이 없어요. 먼저 등록해 주세요'
            : '${member.name}님은 남은 회차가 없어요. 재등록이 필요해요',
      );
      return;
    }

    final done = await showFullPage<bool>(
      context,
      (_) => _SignScreen(member: member),
    );
    // 싸인을 받았으면 선택 화면도 닫고 업무 탭으로 돌아간다
    if (done == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final mineCount = _LessonStore.instance.myMembers.length;

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
                      ModeSwitch(
                        left: '내 담당 ($mineCount)',
                        right: '전체',
                        value: _all,
                        onChanged: (v) => setState(() => _all = v),
                      ),
                      SizedBox(height: 12),
                      if (list.isEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(4, 10, 4, 10),
                          child: Text(
                            _search.text.trim().isEmpty
                                ? '등록된 회원이 없어요'
                                : '검색 결과가 없어요',
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
          GlassSearchBar(controller: _search, hint: '회원 이름 검색'),
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
    final ownerLabel = member.mine ? '내 담당' : '${member.owner} 담당';
    final hasRegistration = member.registration != null;

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
                      if (hasRegistration) ...[
                        SizedBox(width: 6),
                        _MemberBadge(isNew: member.isNew),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    hasRegistration
                        ? '${member.done}/${member.total}회차 사용 · $ownerLabel'
                        : '등록권 없음 · $ownerLabel',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            // 남은 회차 배지
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: member.canSign
                    ? AppColors.gray100
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                member.canSign ? '${member.remaining}회 남음' : '재등록 필요',
                style: AppTextStyles.caption.copyWith(
                  color: member.canSign
                      ? AppColors.textSecondary
                      : AppColors.error,
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

  /// 서명 당시 패드 크기 — 이 크기로 PNG를 굽는다
  Size _padSize = Size.zero;

  bool _saving = false;

  bool get _signed => _strokes.any((stroke) => stroke.length > 1);

  void _clear() => setState(_strokes.clear);

  Future<void> _complete() async {
    if (!_signed) {
      AppToast.show(context, '먼저 싸인을 받아주세요');
      return;
    }
    if (_saving) return;

    final member = widget.member;
    final registration = member.registration;
    if (registration == null) {
      AppToast.show(context, '등록권이 없어 기록할 수 없어요');
      return;
    }

    setState(() => _saving = true);
    try {
      final image = await _encodeSignature(_strokes, _padSize);
      final result = await SessionSignApi.create(
        registrationId: registration.id,
        signatureBase64: image,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        '${member.name}님 ${result.sign.sessionNo}회차 수업이 기록되었습니다',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, messageOf(error));
    }
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
          // 하단 고정: 완료 버튼
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomActionBar(
              children: [
                Expanded(
                  child: BottomActionButton(
                    id: 'sign-done',
                    label: _saving ? '기록 중...' : '싸인 완료',
                    // 서명해야 채워진 상태가 되고,
                    // 미서명 시 동작은 _complete에서 무시한다
                    filled: _signed && !_saving,
                    onPressed: _complete,
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

/// 서명 획을 그리는 페인터
class _SignPainter extends CustomPainter {
  _SignPainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

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
