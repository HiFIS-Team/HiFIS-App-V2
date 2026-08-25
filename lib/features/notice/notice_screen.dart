import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/notice/notice_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/layout.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/display/avatar.dart';
import '../../core/widgets/display/progress_bar.dart';
import '../../core/widgets/editor/block_editor.dart';
import '../../core/widgets/editor/markdown_view.dart';
import '../../core/widgets/editor/post_actions.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/empty_card.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/input/mode_switch.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/phone_scaffold.dart';
import '../../core/util/when.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/failed_card.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/util/screen_refresh.dart';
import '../../core/util/skeleton_delay.dart';
import '../notifications/notification_screen.dart';

part 'notice_phone.dart';
part 'notice_list.dart';
part 'notice_body.dart';
part 'notice_data.dart';

/// 공지 화면
///
/// 데스크톱은 좌측 목록 + 우측 본문 2단 구조. 본문은 회의록과 같은
/// 블록 편집기로 적고, 평소에는 렌더링된 모습으로 읽는다.
/// 폰은 같은 내용을 목록 화면 + 본문 화면 두 장으로 나눠 보여준다.
/// 열어보면 서버에 읽음이 찍히고, 누가 확인했는지 아래에서 볼 수 있다.
///
/// 새 글은 '공지 작성'을 누르면 **빈 글로 시작**해서 편집을 마칠 때 올라간다.
/// 누를 때마다 올리면 쓰다 말고 나갈 때마다 서버에 빈 공지가 쌓인다.
class NoticeScreen extends StatefulWidget {
  NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen>
    with ScreenRefresh<NoticeScreen>, SkeletonDelay<NoticeScreen> {
  /// true면 안 읽은 공지만
  bool _unreadOnly = false;

  _Notice? _selected;

  /// 새로 쓴 공지는 바로 편집 모드로 연다
  bool _startEditing = false;

  /// 탭에 다시 들어오거나 앱이 다시 앞으로 나왔을 때 조용히 다시 받는다
  @override
  Future<void> onScreenRefresh() => _load();

  @override
  void initState() {
    super.initState();
    // 받아 둔 목록이 있으면 뼈대 없이 시작한다 (다시 열 때 안 깜빡인다)
    if (_noticesLoaded) skipFirstSkeleton();
    // 홈에서 넘어오며 걸어둔 요청은 첫 빌드 전에 반영한다 (setState 필요 없음)
    _consumeRequest();
    requestedNotice.addListener(_onRequest);
    _load();
  }

  /// 못 받았다 — **목록이 비어 있을 때만** 실패 카드를 낸다
  ///
  /// 받아 둔 목록이 있으면 그걸 그대로 보여주는 게 낫다. 새로고침 한 번
  /// 실패했다고 이미 읽던 화면을 지우면 잃는 게 더 크다.
  bool _failed = false;

  Future<void> _load() async {
    try {
      await _loadNotices();
      _failed = false;
    } catch (error) {
      _failed = true;
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(endLoad);
  }

  void _retry() {
    setState(beginLoad);
    _load();
  }

  @override
  void dispose() {
    requestedNotice.removeListener(_onRequest);
    super.dispose();
  }

  void _onRequest() {
    if (_consumeRequest()) setState(() {});
  }

  /// 대기 중인 요청이 있으면 선택에 반영한다.
  /// 비우면서 리스너가 한 번 더 돌지만 값이 null이라 바로 빠져나온다.
  bool _consumeRequest() {
    final brief = requestedNotice.value;
    if (brief == null) return false;
    requestedNotice.value = null;
    final notice = brief._notice;
    // 홈에서 열었으니 읽음 처리도 같이 한다
    _markRead(notice);
    _unreadOnly = false;
    _startEditing = false;
    _selected = notice;
    return true;
  }

  List<_Notice> get _visible {
    final list = _notices.where((n) => !_unreadOnly || !n.read).toList();
    // 고정 공지가 위, 그다음 최신순
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.date.compareTo(a.date);
    });
    return list;
  }

  _Notice? _syncSelection(List<_Notice> list) {
    if (list.isEmpty) return null;
    if (_selected != null && list.contains(_selected)) return _selected;
    return list.first;
  }

  /// 공지를 열면 읽은 것으로 표시한다
  void _open(_Notice notice) {
    setState(() {
      _selected = notice;
      _startEditing = false;
      _markRead(notice);
    });
  }

  /// 빈 글로 시작한다 — 서버에는 편집을 마칠 때 올린다
  void _create() {
    final notice = _Notice(
      title: '',
      body: '',
      author: me,
      date: DateTime.now(),
    );
    setState(() {
      _notices.add(notice);
      _unreadOnly = false;
      _selected = notice;
      _startEditing = true;
    });
  }

  /// 편집을 마쳤다 — 여기서 서버에 올리거나 고친다
  Future<void> _finishEditing(_Notice notice) async {
    setState(() => _startEditing = false);
    final isNew = notice.id == null;
    try {
      await _saveNotice(notice);
      if (!mounted) return;
      // 아무것도 안 적고 끝낸 새 글은 목록에 남기지 않는다
      if (notice.id == null) {
        setState(() {
          _notices.remove(notice);
          _selected = null;
        });
        return;
      }
      setState(() {});
      AppToast.show(context, isNew ? '공지를 올렸어요' : '공지를 수정했어요');
    } catch (error) {
      if (!mounted) return;
      // 실패하면 적던 내용을 지키기 위해 편집 상태로 되돌린다
      setState(() => _startEditing = true);
      AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _delete(_Notice notice) async {
    // 전 직원이 보는 글이라 한 번 더 묻는다 — 문서함 폴더와 같은 기준이다
    final ok = await showConfirmDialog(
      context,
      title: '이 공지를 지울까요?',
      message: '지우면 되돌릴 수 없어요.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _deleteNotice(notice);
      if (!mounted) return;
      setState(() => _selected = null);
      AppToast.show(context, '공지를 삭제했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showSkeleton) {
      if (!isDesktop) return _NoticeSkeleton();
      return SkeletonTwoPane(rows: 6);
    }

    final list = _visible;
    final unread = _notices.where((n) => !n.read).length;

    if (!isDesktop) {
      return _NoticePhone(
        notices: list,
        // 못 받았고 보여줄 것도 없을 때만 다시 받기를 낸다
        onRetry: _failed && list.isEmpty ? _retry : null,
        unreadOnly: _unreadOnly,
        unread: unread,
        onFilter: (v) => setState(() => _unreadOnly = v),
        onChanged: () => setState(() {}),
      );
    }

    final selected = _syncSelection(list);
    // 목록을 처음 그릴 때 자동으로 고른 공지도 읽음 처리한다
    if (selected != null && !selected.read) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _markRead(selected));
      });
    }

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 320,
            child: ColoredBox(
              color: AppColors.surface,
              child: _NoticeList(
                notices: list,
                onRetry: _failed && list.isEmpty ? _retry : null,
                selected: selected,
                unreadOnly: _unreadOnly,
                unread: unread,
                onFilter: (v) => setState(() {
                  _unreadOnly = v;
                  _selected = null;
                }),
                onSelect: _open,
                onCreate: _create,
              ),
            ),
          ),
          Container(width: 1, color: AppColors.gray100),
          Expanded(
            child: selected == null
                ? _EmptyNotice(unreadOnly: _unreadOnly, onCreate: _create)
                : _NoticeView(
                    // 공지를 바꾸면 편집 상태를 새로 시작한다
                    key: ValueKey(selected),
                    notice: selected,
                    editing: _startEditing,
                    onChanged: () => setState(() {}),
                    onDelete: () => _delete(selected),
                    onToggleEdit: () => _startEditing
                        ? _finishEditing(selected)
                        : setState(() => _startEditing = true),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 홈 카드 연결 ──

/// 홈 카드에서 열어달라고 요청한 공지
///
/// 폰은 홈에서 바로 본문을 밀어 올리지만, 데스크톱은 2단 구조라
/// 공지 화면으로 옮긴 뒤 이걸 보고 선택을 맞춘다.
final requestedNotice = ValueNotifier<NoticeBrief?>(null);

/// 홈 카드에 내보내는 공지 요약
///
/// 내부 모델(`_Notice`)은 이 라이브러리 밖으로 나가지 않는다.
class NoticeBrief {
  NoticeBrief._(this._notice);

  final _Notice _notice;

  String get title => _notice.displayTitle;
  String get author => _notice.author;
  bool get pinned => _notice.pinned;
  bool get unread => !_notice.read;

  /// '오늘' · '어제' · '7.12'
  ///
  /// 칭찬·설문·수업 기록과 같은 규칙이다. 예전에는 여기만 2~6일을
  /// `3일 전` 으로 적었다.
  String get time => dayLabel(_notice.date);

  /// 폰: 읽음 처리하고 본문을 옆에서 밀어 연다
  Future<void> open(BuildContext context) {
    _markRead(_notice);
    return Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => _NoticePage(notice: _notice, editing: false),
      ),
    );
  }
}

/// 홈 카드용 — 관련 알림 최신순, 없으면 생성순으로 [count]개까지
List<NoticeBrief> noticeBriefs(int count) {
  final list = [..._notices]
    ..sort((a, b) {
      final aActivity = a.id == null
          ? null
          : latestNotificationAt('notices', a.id!);
      final bActivity = b.id == null
          ? null
          : latestNotificationAt('notices', b.id!);
      return (bActivity ?? b.date).compareTo(aActivity ?? a.date);
    });
  return list.take(count).map(NoticeBrief._).toList();
}

/// 올라온 공지 수 (홈 카드 머리말)
int get noticeCount => _notices.length;

/// 홈에서 공지 목록을 채운다
///
/// 홈 카드가 [noticeBriefs]·[noticeCount] 로 같은 목록을 읽는데, 그건
/// 공지 탭을 한 번 열어야 채워진다. **홈부터 보면 카드가 비어 보인다.**
/// 실패해도 홈은 떠야 하므로 조용히 넘긴다 (공지 탭에서 다시 시도한다).
Future<void> loadNoticesIfNeeded() async {
  if (_noticesLoaded) return;
  try {
    await _loadNotices();
  } catch (_) {
    // 서버가 꺼져 있다 — 카드는 '올라온 공지가 없어요' 로 남는다
  }
}
