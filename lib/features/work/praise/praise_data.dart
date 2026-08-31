part of 'praise_section.dart';

/// 컴플레인 처리 단계 (칭찬에는 쓰지 않는다)
enum _Status {
  pending('미처리'),
  working('해결중'),

  /// 완료를 올렸고 대표가 아직 안 봤다 (2026-08-31)
  waiting('완료 승인 대기'),
  done('해결 완료');

  const _Status(this.label);

  final String label;

  Color get color => switch (this) {
    _Status.pending => AppColors.warning,
    _Status.working => AppColors.primary,
    // 대기는 '아직 안 끝났다' 쪽이라 미처리와 같은 주황을 쓴다
    _Status.waiting => AppColors.warning,
    _Status.done => AppColors.success,
  };

  ComplaintStatus get wire => switch (this) {
    _Status.pending => ComplaintStatus.pending,
    _Status.working => ComplaintStatus.working,
    // 대기는 서버가 매기는 값이라 보낼 일이 없다 — 누르는 건 늘 '완료'다
    _Status.waiting => ComplaintStatus.done,
    _Status.done => ComplaintStatus.done,
  };

  static _Status of(ComplaintStatus status) => switch (status) {
    ComplaintStatus.pending => _Status.pending,
    ComplaintStatus.working => _Status.working,
    ComplaintStatus.doneRequested => _Status.waiting,
    ComplaintStatus.done => _Status.done,
  };
}

/// 회원이 남긴 피드백 한 건 (칭찬 또는 컴플레인)
///
/// 설문 한 건에서 최대 두 줄이 나온다 — 칭찬 한 줄, 개선 의견 한 줄.
/// 그래서 [surveyId] 가 둘이 같을 수 있다.
class _Feedback {
  _Feedback({
    required this.name,
    required this.colorValue,
    required this.text,
    required this.time,
    this.surveyId,
    this.complaint = false,
    this.status = _Status.pending,
    this.about,
  });

  /// 원본 설문 id — 처리 단계를 서버에 올릴 때 쓴다
  final String? surveyId;

  final String name;
  final int colorValue;
  final String text;
  final DateTime time;
  final bool complaint;

  /// 컴플레인 처리 단계 — 상세 화면에서 바꾼다
  _Status status;

  /// 누구에게 온 것인지 — **전사로 볼 때만** 채운다 (본인 것만 볼 때는 뻔하다)
  final String? about;

  Color get color => Color(colorValue);
}

/// 현장 업무를 안 하는 사람 — 대표·관리자
///
/// 설문은 트레이너를 칭찬하는 것이라 대표·관리자는 받을 일이 없다.
/// 본인 것으로 거르면 늘 비어서, 대신 **전사 칭찬·컴플레인**을 조회로 본다.
bool get _viewOnly => !(currentUser?.role.doesFieldWork ?? true);

/// 컴플레인 처리 단계 UI를 그릴지
///
/// 예전에는 폰에서만 그렸는데, 컴플레인을 챙기는 대표·관리자가 PC 를 쓴다.
/// PC 에서 버튼이 없으면 아무도 해결을 못 찍는다.
bool get _showStatus => true;

/// 서버에서 받은 설문 — 화면 셋이 같이 쓴다
///
/// **한 번만 받아 둘로 나눈다.** '전체' 탭은 설문 원본을 그대로 보고,
/// '내게 온 칭찬'·'컴플레인' 은 그중 내가 칭찬받은 것만 줄로 편다
/// (설문 하나에서 칭찬 한 줄 · 개선 의견 한 줄이 나온다).
final _feedbacks = <_Feedback>[];
final _surveys = <_Survey>[];

Future<void> _loadSurveys({String? branchId}) async {
  final rows = await KindnessApi.list(branchId: branchId);
  final me = currentUser?.id;

  _surveys
    ..clear()
    ..addAll([
      for (final row in rows)
        _Survey(
          id: row.id,
          name: row.memberName,
          phone: row.memberPhone,
          colorValue: avatarColorFor(row.memberName).toARGB32(),
          motive: row.motivation,
          praised:
              StaffDirectory.instance.byId(row.praisedEmployeeId)?.name ?? '',
          improve: row.improvement ?? '',
          consent: row.consent,
          time: row.submittedAt,
        ),
    ]);

  _feedbacks
    ..clear()
    ..addAll([
      for (final row in rows)
        // 직원·점장은 본인에게 온 것만, 대표·관리자는 전사를 본다
        if (_viewOnly || row.praisedEmployeeId == me) ...[
          if (row.praiseComment.trim().isNotEmpty)
            _Feedback(
              surveyId: row.id,
              name: row.memberName,
              colorValue: avatarColorFor(row.memberName).toARGB32(),
              text: row.praiseComment,
              time: row.submittedAt,
              about: _viewOnly ? _employeeName(row.praisedEmployeeId) : null,
            ),
          if (row.isComplaint)
            _Feedback(
              surveyId: row.id,
              name: row.memberName,
              colorValue: avatarColorFor(row.memberName).toARGB32(),
              text: row.improvement!,
              time: row.submittedAt,
              complaint: true,
              status: _Status.of(row.improvementStatus),
              about: _viewOnly ? _employeeName(row.praisedEmployeeId) : null,
            ),
        ],
    ]);

  // **여기서 한 번만 정렬한다.** 최신순은 이 두 목록의 성질이지 화면마다
  // 다시 정하는 값이 아니다. 예전에는 읽는 자리 다섯 곳이 저마다 정렬해서,
  // 같은 목록을 한 화면에서 여러 번 줄 세웠다.
  // 걸러 낸 목록도 순서를 물려받으므로 읽는 쪽은 그냥 쓰면 된다.
  _surveys.sort((a, b) => b.time.compareTo(a.time));
  _feedbacks.sort((a, b) => b.time.compareTo(a.time));
}

/// 설문이 가리키는 직원 이름 — 명단에 없으면 빈 값
String? _employeeName(String id) {
  final name = StaffDirectory.instance.byId(id)?.name;
  return name == null || name.isEmpty ? null : name;
}

/// '7.29 오후 5:36' 형태
String _formatStamp(DateTime time) {
  final period = time.hour < 12 ? '오전' : '오후';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.month}.${time.day} $period $hour:$minute';
}

/// 피드백 줄을 누르면 전체 내용을 크게 보여준다.
/// 컴플레인이면 아래에 처리 단계 버튼이 붙고, 바꾸면 [onChanged]로 목록을 새로 그린다.
void _showFeedbackDetail(
  BuildContext context,
  _Feedback feedback, {
  VoidCallback? onChanged,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '피드백 크게 보기',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: _FeedbackDetailCard(feedback: feedback, onChanged: onChanged),
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

/// 바뀐 단계를 서버에 올린다 — 실패하면 되돌린다
///
/// 창이 이미 닫힌 뒤라 여기서 토스트를 띄울 자리가 없다. 실패하면 목록의
/// 알약이 원래 색으로 돌아가는 것이 신호다. 그래서 위젯이 아니라 값만
/// 넘겨받는다 (닫힌 위젯의 `widget` 을 만지면 터진다).
/// 컴플레인을 지운 뒤 화면에서도 뺀다
///
/// **서버는 개선 의견만 비운다** — 칭찬 줄과 설문 원본은 그대로 있어야 한다.
/// 그래서 컴플레인 줄만 빼고 설문의 개선 칸을 비운다.
void _dropComplaint(String surveyId) {
  _feedbacks.removeWhere((f) => f.complaint && f.surveyId == surveyId);
  for (final survey in _surveys) {
    if (survey.id == surveyId) survey.improve = '';
  }
}

Future<void> _push(
  String id,
  _Feedback feedback,
  _Status next,
  _Status before,
  VoidCallback? onChanged,
) async {
  try {
    await KindnessApi.setStatus(id, next.wire);
  } catch (_) {
    feedback.status = before;
    onChanged?.call();
  }
}
