import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/work/lesson_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/glass/glass_bottom_button.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/glass_search_bar.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/display/progress_bar.dart';
import '../../core/widgets/input/see_all_button.dart';

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
/// 현장 업무를 안 하는 사람 — 대표·관리자
///
/// 서버가 세션 싸인·회원 등록을 MEMBER·MANAGER 로만 열어 뒀다
/// (backend-gap 24번). 눌러도 403 이 나므로 버튼을 아예 안 보여주고
/// 대신 **지점 전체 기록**을 조회로 보여준다.
bool get _viewOnly => !(currentUser?.role.doesFieldWork ?? true);

/// 싸인을 받은 트레이너 이름 — 전사 기록에서 누구 건지 가르는 값
String _trainerName(SessionSign sign) =>
    StaffDirectory.instance.byId(sign.performedByTrainerId)?.name ?? '알 수 없음';

class _LessonStore {
  _LessonStore._();

  static final _LessonStore instance = _LessonStore._();

  List<Member> members = const [];
  List<Registration> registrations = const [];

  /// 이번 달 싸인 — 지난 달은 기록 화면에서 따로 받는다
  ///
  /// 한 트레이너가 월 50회면 1년에 600건이라, 전부 받으면 화면 열 때마다
  /// 그게 다 넘어온다. 달로 잘라 받는다.
  List<SessionSign> signs = const [];

  Future<void> load() async {
    final now = DateTime.now();
    // 셋 다 서로를 안 기다려도 되니 같이 띄운다
    final memberRequest = MemberApi.list();
    final registrationRequest = RegistrationApi.list();
    final signRequest = SessionSignApi.list(
      // 대표·관리자는 자기 싸인이 없다 — 안 주면 서버가 지점 전체를 준다
      trainerId: _viewOnly ? null : currentUser?.id,
      period: periodKey(now),
    );

    members = await memberRequest;
    registrations = await registrationRequest;
    signs = await signRequest;
  }

  /// 최신순으로 세운다 — 서버가 기록 표시에 필요한 값을 이미 채워 준다
  List<SessionSign> sorted(List<SessionSign> rows) =>
      [...rows]..sort((a, b) => b.signedAt.compareTo(a.signedAt));

  /// 회원이 지금 쓰는 등록권
  ///
  /// 회차가 남은 것 중 **먼저 산 것**. 다 쓰기 전에 재등록하면 등록권이
  /// 잠깐 둘이 되는데, 남은 회차를 흘리지 않으려면 먼저 산 걸 먼저 써야 한다.
  /// 남은 게 하나도 없으면 마지막 등록권을 준다 — "20/20회차 사용"까지는
  /// 보여줘야 재등록하러 갈 수 있다.
  Registration? currentRegistrationOf(String memberId) {
    Registration? active;
    Registration? latest;
    for (final registration in registrations) {
      if (registration.memberId != memberId) continue;
      if (latest == null ||
          registration.purchasedAt.isAfter(latest.purchasedAt)) {
        latest = registration;
      }
      if (registration.exhausted) continue;
      if (active == null ||
          registration.purchasedAt.isBefore(active.purchasedAt)) {
        active = registration;
      }
    }
    return active ?? latest;
  }

  /// 내가 담당하는 회원
  List<_LessonMember> get myMembers => [
    for (final member in members)
      if (member.ownerTrainerId == currentUser?.id)
        _LessonMember(
          source: member,
          registration: currentRegistrationOf(member.id),
        ),
  ];

  /// 화면에 세우는 이번 달 싸인 (최신순)
  ///
  /// 직원·점장은 본인 것, 대표·관리자는 지점 전체다 — 받아올 때 갈린다.
  List<SessionSign> get shownSigns => sorted(signs);
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
}

/// 기록 한 줄에 쓰는 표시용 값
///
/// 서버가 조인해서 내려 준다. 지난 달 기록을 볼 때도 등록권 목록 없이
/// 이것만으로 그려진다.
extension _SignDisplay on SessionSign {
  String get displayName => memberName ?? '알 수 없음';

  /// '12/20회차' — 총 회차를 모르는 옛 기록이면 '12회차'
  String get roundLabel =>
      totalSessions == null ? '$sessionNo회차' : '$sessionNo/$totalSessions회차';

  bool get isNewRegistration => registrationType == RegistrationType.newMember;
}

/// 서명 이미지를 화면 배율의 몇 배까지 키워 구울지
///
/// 3배면 어느 기기든 화면에 보이는 만큼은 선명하다. 그 위로는 파일만
/// 커지고 눈에 띄는 차이가 없어서 잘라 둔다.
const _signatureMaxScale = 3.0;

/// 서명 획을 PNG base64 로 만든다 — 서버는 좌표가 아니라 이미지를 받는다
///
/// 그림으로 저장해야 나중에 그리는 코드가 바뀌어도 회원이 실제로 쓴
/// 싸인이 그대로 남는다. 좌표만 두면 증거로 쓸 수 없다.
///
/// [pixelRatio] 는 화면 배율. 논리 크기 그대로 구우면 레티나에서 그린 것보다
/// 해상도가 절반~1/3로 떨어져 확대했을 때 뭉갠다. 서명은 나중에 본인 확인
/// 자료로 꺼내 보는 것이라 그린 대로 남아야 한다.
Future<String> _encodeSignature(
  List<List<Offset>> strokes,
  Size size, {
  required double pixelRatio,
}) async {
  final scale = pixelRatio.clamp(1.0, _signatureMaxScale);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // 좌표는 논리 크기 그대로 두고 캔버스만 키운다 — 획 두께도 같이 커져서
  // 화면에서 본 모양 그대로 해상도만 올라간다
  canvas.scale(scale);
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
    (size.width * scale).round(),
    (size.height * scale).round(),
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
void _showSignDetail(BuildContext context, SessionSign sign) {
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
                child: _SignImage(url: sign.signatureFullUrl),
              ),
              SizedBox(height: 14),
              Text(
                '${sign.displayName} · ${sign.roundLabel}',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(_formatStamp(sign.signedAt), style: AppTextStyles.caption),
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

    // 상단 액션 버튼 두 개 — 폰·PC 공통. 대표·관리자는 수행자가 아니라 안 그린다
    final actions = _viewOnly
        ? SizedBox.shrink()
        : Row(
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
          );

    // 폰은 싸인마다 카드 하나 (회원 친절도 목록과 같은 결).
    // 데스크톱은 2단 화면이라 카드가 과해서 기존 줄 목록을 그대로 쓴다.
    if (!isDesktop) {
      final sorted = _LessonStore.instance.shownSigns;
      // 목록에는 최근 5건만 — 나머지는 전체 보기 화면에서
      final recent = sorted.take(5).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          actions,
          if (!_viewOnly) SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  '세션 기록',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8),
                Text('${sorted.length}', style: AppTextStyles.caption),
                Spacer(),
                SeeAllButton(onTap: _openHistory),
              ],
            ),
          ),
          SizedBox(height: 12),
          if (recent.isEmpty)
            EmptyCard(icon: Icons.draw_rounded, text: '아직 받은 싸인이 없어요')
          else
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) SizedBox(height: 12),
              _SignCard(
                sign: recent[i],
                onTap: () => _showSignDetail(context, recent[i]),
              ),
            ],
        ],
      );
    }

    return Column(
      children: [
        // 월 목표·담당 회원은 본인 기준이라 대표·관리자에게는 뜻이 없다
        if (!_viewOnly) ...[
          _SessionGoalCard(),
          SizedBox(height: 16),
          actions,
          SizedBox(height: 16),
        ],
        _buildRecordCard(),
      ],
    );
  }

  Widget _buildRecordCard() {
    final sorted = _LessonStore.instance.shownSigns;
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
/// 폰 목록 카드 — 회원 친절도·동료 평가 목록과 같은 결로 싸인 하나에 카드 하나
///
/// 데스크톱은 아직 [_SignRow] 를 쓴다 (2단 화면이라 카드가 과하다).
class _SignCard extends StatelessWidget {
  _SignCard({required this.sign, required this.onTap});

  final SessionSign sign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sign.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        // 전사 기록에서는 누가 받았는지가 먼저다
                        _viewOnly
                            ? '${_trainerName(sign)} · '
                                  '${_formatStamp(sign.signedAt)}'
                            : _formatStamp(sign.signedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                _MemberBadge(isNew: sign.isNewRegistration),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                // 서명 미리보기 — 이 기록의 증거라 카드에서도 크게 둔다
                Container(
                  width: 92,
                  height: 52,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray100),
                  ),
                  child: _SignImage(url: sign.signatureFullUrl),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sign.roundLabel,
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '+1',
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignRow extends StatelessWidget {
  _SignRow({required this.sign, required this.onTap});

  final SessionSign sign;
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
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gray100),
            ),
            child: _SignImage(url: sign.signatureFullUrl),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      sign.displayName,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6),
                    _MemberBadge(isNew: sign.isNewRegistration),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  // 전사 기록에서는 누가 받았는지가 먼저다
                  _viewOnly
                      ? '${_trainerName(sign)} · ${sign.roundLabel}'
                            ' · ${_formatStamp(sign.signedAt)}'
                      : '${sign.roundLabel} · ${_formatStamp(sign.signedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

/// 기록 화면 상단의 달 넘김 줄
class _MonthBar extends StatelessWidget {
  _MonthBar({
    required this.month,
    required this.count,
    required this.loading,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final int count;
  final bool loading;
  final VoidCallback onPrev;

  /// null 이면 더 갈 데가 없다 (이번 달)
  final VoidCallback? onNext;

  Widget _arrow(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap ?? () {},
      scale: enabled ? 0.9 : 1,
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? AppColors.textSecondary : AppColors.gray300,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 24, 6),
      child: Row(
        children: [
          _arrow(CupertinoIcons.chevron_left, onPrev),
          Text(
            '${month.year}년 ${month.month}월',
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w700),
          ),
          _arrow(CupertinoIcons.chevron_right, onNext),
          Spacer(),
          Text(
            loading ? '불러오는 중' : '총 $count건',
            style: AppTextStyles.caption.copyWith(
              color: loading ? AppColors.textTertiary : AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 세션 기록 전체 화면 — 달을 넘겨 가며 날짜별로 묶어 보여준다
///
/// 싸인은 달마다 따로 받는다. 한 번에 다 받으면 해가 갈수록
/// 화면 열 때마다 몇 백 건씩 넘어온다.
class _SignHistoryScreen extends StatefulWidget {
  @override
  State<_SignHistoryScreen> createState() => _SignHistoryScreenState();
}

class _SignHistoryScreenState extends State<_SignHistoryScreen> {
  final _search = TextEditingController();

  late DateTime _month;
  List<SessionSign> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _search.addListener(() => setState(() {}));
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 다음 달로 못 넘어간다 — 아직 오지 않은 달이라 볼 게 없다
  bool get _atLatest {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final rows = await SessionSignApi.list(
        trainerId: currentUser?.id,
        period: periodKey(_month),
      );
      if (!mounted) return;
      setState(() {
        _rows = _LessonStore.instance.sorted(rows);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _fetch();
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
    final all = _rows;
    final query = _search.text.trim();
    final sorted = all
        .where((s) => query.isEmpty || s.displayName.contains(query))
        .toList();

    // 날짜가 바뀌는 지점마다 그룹 헤더를 끼워 넣는다
    final children = <Widget>[];
    String? label;
    for (final sign in sorted) {
      final dayLabel = _dayLabel(sign.signedAt);
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
                _MonthBar(
                  month: _month,
                  count: sorted.length,
                  loading: _loading,
                  onPrev: () => _shiftMonth(-1),
                  // 아직 오지 않은 달은 볼 게 없으니 막는다
                  onNext: _atLatest ? null : () => _shiftMonth(1),
                ),
                Container(height: 1, color: AppColors.gray100),
                if (_loading)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 40, 24, 44),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  )
                else if (sorted.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                    child: Text(
                      all.isEmpty ? '이 달에 받은 싸인이 없어요' : '검색 결과가 없어요',
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
        // 회원과 첫 등록권을 한 트랜잭션으로 만든다 — 둘로 나눠 부르면
        // 등록권에서 실패했을 때 등록권 없는 회원이 남는다
        final name = _name.text.trim();
        await MemberApi.create(
          name: name,
          phone: _phone.text.trim(),
          branchId: me.branchId,
          ownerTrainerId: me.id,
          referrerMemberId: _referrer?.id,
          type: RegistrationType.newMember,
          totalSessions: _roundCount,
          pricePaid: _paymentWon,
          sessionUnitPrice: _unitPrice,
        );
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
///
/// 내 담당 회원만 나온다. 남의 회원 싸인을 대신 받으면 서버가 커미션과
/// 수업왕 점수를 **수행한 사람** 기준으로 붙여서 매출 귀속이 어긋난다.
/// 우리는 대타로 수업하는 일이 없다.
class _PickMemberScreen extends StatefulWidget {
  @override
  State<_PickMemberScreen> createState() => _PickMemberScreenState();
}

class _PickMemberScreenState extends State<_PickMemberScreen> {
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
    final base = _LessonStore.instance.myMembers;
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
                    '내 담당 회원 ${list.length}명',
                    style: AppTextStyles.caption,
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      MediaQuery.paddingOf(context).bottom + 96,
                    ),
                    children: [
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
                        ? '${member.done}/${member.total}회차 사용'
                        : '등록권 없음',
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

    // 굽기 전에 읽어 둔다 — await 뒤에는 context 를 쓰지 않는다
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    setState(() => _saving = true);
    try {
      final image = await _encodeSignature(
        _strokes,
        _padSize,
        pixelRatio: pixelRatio,
      );
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
