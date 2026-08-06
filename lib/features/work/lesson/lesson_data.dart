part of 'lesson_section.dart';

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

  Future<void> load({String? branchId}) async {
    final now = DateTime.now();
    // 셋 다 서로를 안 기다려도 되니 같이 띄운다
    final memberRequest = MemberApi.list(branchId: branchId);
    final registrationRequest = RegistrationApi.list();
    final signRequest = SessionSignApi.list(
      // 대표·관리자는 자기 싸인이 없다 — 안 주면 서버가 지점 전체를 준다
      trainerId: _viewOnly ? null : currentUser?.id,
      period: periodKey(now),
      branchId: branchId,
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
