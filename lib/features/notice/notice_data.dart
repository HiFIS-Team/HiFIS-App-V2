part of 'notice_screen.dart';

// ── 데이터 ──

/// 공지 한 건 — 본문은 마크다운 원문 그대로 담는다
class _Notice {
  _Notice({
    required this.title,
    required this.body,
    required this.author,
    required this.date,
    this.id,
    this.authorId,
    this.pinned = false,
    this.read = false,
    this.readCount = 0,
    List<ReactionAgg>? reactions,
  }) : reactions = reactions ?? [];

  /// 서버가 준 uuid — **null 이면 아직 안 올린 새 글이다.**
  /// '공지 작성'을 누르면 빈 글로 시작해서, 편집을 마칠 때 서버에 올린다.
  String? id;

  /// 작성자 uuid — 수정·삭제 권한이 이 값으로 갈린다 ([_canEdit])
  String? authorId;

  String title;
  String body;
  final String author;
  final DateTime date;

  /// 상단 고정 (중요 공지)
  bool pinned;

  /// 내가 열어 봤는지 (서버 `readByMe`)
  bool read;

  /// 확인한 사람 수 (서버 `readCount`).
  /// 전체 인원과 사람별 목록은 `/notices/{id}/readers` 로 따로 받는다.
  int readCount;

  /// 이모지별 누른 사람 — 토글하면 서버가 준 최신 집계로 통째로 갈아끼운다
  List<ReactionAgg> reactions;

  String get displayTitle => title.isEmpty ? '제목 없는 공지' : title;

  /// 목록에 보여줄 첫 줄 (마크다운 기호는 떼고)
  String get preview {
    for (final line in body.split('\n')) {
      final text = line
          .replaceAll(RegExp(r'^(#{1,3} |[-*] \[[ xX]\] |[-*] |> |\d+\. )'), '')
          .replaceAll(RegExp(r'[*`~]'), '')
          .trim();
      if (text.isNotEmpty) return text;
    }
    return '내용 없음';
  }
}

/// 올라온 공지 — 서버에서 받아 온다.
/// 탭을 오가도 다시 받지 않도록 모듈 전역으로 둔다.
final _notices = <_Notice>[];

/// 한 번이라도 받아왔는지 — 탭을 다시 열 때 빈 목록을 깜빡이지 않게 한다
bool _noticesLoaded = false;

/// 로그아웃 때 비운다 — **다음 사람에게 앞사람 것이 보이면 안 된다**
void resetNoticeCache() {
  _notices.clear();
  _noticesLoaded = false;
}

Future<void> _loadNotices() async {
  final rows = await NoticeApi.list();
  // 목록을 새로 받는 김에 확인 현황도 버린다 —
  // 그 사이 남들이 읽었을 수 있어서 들고 있던 값은 이미 옛것이다
  _readersCache.clear();
  _notices
    ..clear()
    ..addAll([for (final row in rows) _fromServer(row)]);
  _noticesLoaded = true;
}

/// 서버 공지 → 화면 모델
///
/// 서버는 작성자를 uuid 로 주는데 화면은 이름으로 아바타·직군을 찾는다.
/// 명단에 없으면(퇴사자 등) uuid 대신 빈 이름을 두어 아바타만 회색으로 뜬다.
_Notice _fromServer(Notice row) {
  final author = StaffDirectory.instance.byId(row.authorId);
  return _Notice(
    id: row.id,
    authorId: row.authorId,
    title: row.title,
    body: row.body,
    author: author?.name ?? '',
    date: row.createdAt,
    pinned: row.pinned,
    read: row.readByMe,
    readCount: row.readCount,
    reactions: row.reactions,
  );
}

/// 편집을 마쳤을 때 — 새 글이면 올리고, 있던 글이면 고친다
///
/// 제목·본문이 모두 비었으면 아무것도 안 한다. 빈 글로 시작하는 구조라
/// 작성을 눌렀다가 그냥 나가는 일이 흔한데, 그때마다 서버에 빈 공지가 쌓인다.
Future<void> _saveNotice(_Notice notice) async {
  if (notice.title.trim().isEmpty && notice.body.trim().isEmpty) return;

  final id = notice.id;
  if (id == null) {
    final created = await NoticeApi.create(
      title: notice.title,
      body: notice.body,
      pinned: notice.pinned,
    );
    notice.id = created.id;
    notice.authorId = created.authorId;
    // 내가 쓴 글은 이미 본 것이다 — 서버도 작성자를 읽음으로 잡아 준다
    notice.read = created.readByMe;
    notice.readCount = created.readCount;
    return;
  }

  await NoticeApi.update(
    id,
    title: notice.title,
    body: notice.body,
    pinned: notice.pinned,
  );
}

/// 지우기 — 아직 안 올린 새 글은 서버를 부르지 않는다
Future<void> _deleteNotice(_Notice notice) async {
  final id = notice.id;
  if (id != null) await NoticeApi.delete(id);
  _notices.remove(notice);
  _readersCache.remove(id);
}

/// 열어 봤다고 찍는다
///
/// 화면을 먼저 바꾸고 서버에 알린다. 실패해도 되돌리지 않는다 — 읽음은
/// 다시 열면 또 찍히는 값이라, 여기서 에러를 띄우면 성가시기만 하다.
void _markRead(_Notice notice) {
  final id = notice.id;
  if (id == null || notice.read) return;
  notice.read = true;
  notice.readCount++;
  // 받아 둔 확인 현황에 **나만 읽은 것으로 바꿔 넣는다.**
  //
  // 예전에는 통째로 버렸는데, 그러면 공지를 열 때마다 다시 받게 되고 그동안
  // 카드가 사람 알약 없이 그려졌다가 값이 오면서 커졌다 (항목을 옮길 때
  // 깜빡이던 원인). 바뀌는 건 내 줄 하나뿐이라 여기서 고쳐 넣으면 된다.
  final cached = _readersData[id];
  if (cached != null) {
    final me = currentUser?.id;
    _readersData[id] = NoticeReaders(
      total: cached.total,
      readCount: cached.readCount + 1,
      people: [
        for (final person in cached.people)
          if (person.employeeId == me)
            NoticeReader(
              employeeId: person.employeeId,
              name: person.name,
              avatarColor: person.avatarColor,
              readAt: DateTime.now(),
            )
          else
            person,
      ],
    );
    _readersCache[id] = Future.value(_readersData[id]);
  }
  NoticeApi.markRead(id).catchError((_) {});
}

/// 이 공지를 고치거나 지울 수 있는가
///
/// 서버 기준과 같다 — **작성자 본인 또는 관리자·점장·대표**.
/// 남이 쓴 글을 일반 직원이 건드리면 403 이라 버튼을 감춘다.
///
/// 아직 안 올린 새 글([_Notice.id]가 null)도 열어 둔다. 작성은 누구나 되는데
/// 여기서 막으면 쓰다 말고 저장도 못 하는 상태가 된다.
bool _canEdit(_Notice notice) =>
    notice.id == null || notice.authorId == currentUser?.id || myRole.strong;

// ── 표시용 계산 ──

/// '7.30' 형태
String _date(DateTime time) => dateLabel(time);
