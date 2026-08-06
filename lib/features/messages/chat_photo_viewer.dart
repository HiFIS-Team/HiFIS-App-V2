part of 'chat_screen.dart';

// ── 사진 크게 보기 ──

/// 사진을 눌렀을 때 — 검은 화면에 한 장씩, 좌우로 넘긴다
///
/// **처음에는 사진만 보인다.** 화면을 한 번 누르면 위 머리말이 나타나고
/// 다시 누르면 사라진다 (사진 앱·카톡과 같은 결이다).
///
/// - **아래로 끌어내리면 닫힌다.** 끌어내리는 만큼 배경이 옅어져 뒤 대화가 비친다
/// - 손가락 두 개로 늘려 볼 수 있고, **늘린 상태에서는 넘기기·끌어내리기가 안 걸린다**
///   (사진을 옮기려는 손짓과 겹친다)
void showPhotoViewer(
  BuildContext context,
  List<String> urls,
  int index, {
  required String title,
  required DateTime time,
}) {
  Navigator.push<void>(
    context,
    PageRouteBuilder<void>(
      // 끌어내릴 때 뒤 대화가 비쳐야 해서 불투명 라우트로 두지 않는다
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: 220),
      reverseTransitionDuration: Duration(milliseconds: 180),
      pageBuilder: (_, _, _) =>
          _PhotoViewer(urls: urls, index: index, title: title, time: time),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  _PhotoViewer({
    required this.urls,
    required this.index,
    required this.title,
    required this.time,
  });

  final List<String> urls;
  final int index;

  /// 보낸 사람 이름 — 머리말 첫 줄
  final String title;

  /// 보낸 시각 — 머리말 둘째 줄
  final DateTime time;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pages = PageController(initialPage: widget.index);
  final _zoom = TransformationController();

  late int _at = widget.index;

  /// 아래로 끌어내린 거리
  double _drag = 0;

  /// 손가락으로 늘려 놓은 상태인지
  bool _zoomed = false;

  /// 머리말이 떠 있는지 — 처음에는 사진만 보인다
  bool _chrome = false;

  /// 저장하는 중 (두 번 눌리지 않게)
  bool _saving = false;

  /// 이만큼 끌어내리면 닫는다
  static const _dismissAt = 110.0;

  @override
  void dispose() {
    _pages.dispose();
    _zoom.dispose();
    super.dispose();
  }

  /// 끌어내릴수록 배경이 옅어진다 — 뒤 대화가 비쳐서 어디로 돌아가는지 보인다
  double get _backdrop => (1 - _drag.abs() / 420).clamp(0.25, 1.0);

  /// `2026. 8. 5. 오후 8:47` · 여러 장이면 `· 2 / 5` 를 뒤에 붙인다
  ///
  /// 장수는 카톡처럼 아래에 따로 두지 않고 날짜 옆에 붙인다 — 아래를 비워
  /// 사진을 넓게 쓴다.
  String get _subtitle {
    final t = widget.time;
    final pm = t.hour >= 12;
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final when =
        '${t.year}. ${t.month}. ${t.day}. '
        '${pm ? '오후' : '오전'} $hour12:${t.minute.toString().padLeft(2, '0')}';
    if (widget.urls.length < 2) return when;
    return '$when · ${_at + 1} / ${widget.urls.length}';
  }

  void _onDragEnd(DragEndDetails details) {
    final fast = (details.primaryVelocity ?? 0).abs() > 700;
    if (_drag.abs() > _dismissAt || fast) {
      Navigator.pop(context);
      return;
    }
    setState(() => _drag = 0);
  }

  /// 지금 보고 있는 사진 저장 — 폰은 사진첩, PC 는 파일로
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final url = widget.urls[_at];
    try {
      final bytes = await _bytesOf(url);
      if (!mounted) return;
      if (isDesktop) {
        final target = await FilePicker.saveFile(
          dialogTitle: '사진 저장',
          fileName: _fileNameOf(url),
          bytes: bytes,
        );
        if (!mounted || target == null) return;
        AppToast.show(context, '사진을 저장했어요');
        return;
      }
      await Gal.putImageBytes(bytes, name: _fileNameOf(url));
      if (mounted) AppToast.show(context, '사진첩에 저장했어요');
    } catch (error) {
      if (mounted) {
        AppToast.show(
          context,
          error is GalException ? '사진첩에 저장하지 못했어요' : messageOf(error),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  /// 저장할 바이트 — 방금 올린 것은 기기에 있고, 아니면 서버에서 받는다
  Future<Uint8List> _bytesOf(String url) async {
    if (url.startsWith(localFilePrefix)) {
      return File(url.substring(localFilePrefix.length)).readAsBytes();
    }
    final local = ChatStore.instance.localCopyOf(url);
    if (local != null) {
      final file = File(local);
      if (file.existsSync()) return file.readAsBytes();
    }
    return Uint8List.fromList(await ApiClient.instance.getBytes(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: _backdrop)),
          ),
          Transform.translate(
            offset: Offset(0, _drag),
            child: GestureDetector(
              // 한 번 누르면 머리말이 나왔다 들어간다 (사진 앱과 같다)
              onTap: () => setState(() => _chrome = !_chrome),
              onVerticalDragUpdate: _zoomed
                  ? null
                  : (d) => setState(() => _drag += d.delta.dy),
              onVerticalDragEnd: _zoomed ? null : _onDragEnd,
              child: PageView.builder(
                controller: _pages,
                // 늘려 놓은 상태에서 옆으로 밀면 사진이 움직여야 한다
                physics: _zoomed
                    ? NeverScrollableScrollPhysics()
                    : PageScrollPhysics(),
                itemCount: widget.urls.length,
                onPageChanged: (i) => setState(() {
                  _at = i;
                  // 넘기면 늘린 것을 되돌린다 — 다음 장이 늘어난 채로 뜨면 안 된다
                  _zoom.value = Matrix4.identity();
                  _zoomed = false;
                }),
                itemBuilder: (_, i) => InteractiveViewer(
                  transformationController: _zoom,
                  minScale: 1,
                  maxScale: 4,
                  // 원래 크기일 때는 끌어내리기가 먼저다
                  panEnabled: _zoomed,
                  onInteractionEnd: (_) {
                    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
                    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                  },
                  child: Center(
                    child: chatPhoto(widget.urls[i], fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          _Chrome(
            shown: _chrome,
            title: widget.title,
            subtitle: _subtitle,
            saving: _saving,
            onClose: () => Navigator.pop(context),
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

/// 위 머리말 — 뒤로가기 · 보낸 사람 · 시각 · 저장
///
/// 밝은 사진 위에서도 글자가 보이게 **위쪽에 검정 그라데이션**을 깐다
/// (막대를 통째로 칠하면 사진이 그만큼 잘려 보인다).
class _Chrome extends StatelessWidget {
  _Chrome({
    required this.shown,
    required this.title,
    required this.subtitle,
    required this.saving,
    required this.onClose,
    required this.onSave,
  });

  final bool shown;
  final String title;
  final String subtitle;
  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !shown,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: Duration(milliseconds: 180),
        child: Container(
          height: MediaQuery.paddingOf(context).top + 78,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: CupertinoIcons.chevron_back,
                    onTap: onClose,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body1.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6),
                  _RoundIconButton(
                    icon: saving
                        ? CupertinoIcons.hourglass
                        : CupertinoIcons.arrow_down_to_line,
                    onTap: onSave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 사진 위 동그란 버튼 — 밝은 사진 위에서도 보이게 반투명 검정을 깐다
class _RoundIconButton extends StatelessWidget {
  _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.9,
    child: Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    ),
  );
}

/// 저장할 때 쓸 파일 이름 — 주소 끝에서 뽑고 없으면 시각으로 만든다
String _fileNameOf(String url) {
  final path = url.split('?').first;
  final name = path.substring(path.lastIndexOf('/') + 1);
  if (name.isNotEmpty) return name;
  return 'hifis_${DateTime.now().millisecondsSinceEpoch}.jpg';
}

/// 사내톡 사진 한 장 — 서버 주소든 기기 파일이든 같이 다룬다
///
/// 기기 파일을 쓰는 자리가 둘이다.
/// 1. **보내는 중** — 아직 안 올라간 원본 ([localFilePrefix])
/// 2. **방금 올린 것** — 올라간 뒤에도 기기에 남아 있는 파일 ([ChatStore.localCopyOf]).
///    서버에서 다시 받아 오면 그동안 사진이 사라졌다가 다시 뜬다
/// [cacheWidth] — **말풍선에서는 반드시 준다.**
/// 안 주면 1600px 원본을 그대로 풀어서 한 장이 7MB 넘게 메모리를 먹는다.
/// 사진이 열 몇 장 쌓이면 이미지 캐시(100MB)가 넘쳐 오래된 것부터 버려지고,
/// 스크롤을 올렸다 내리면 **사라졌다가 다시 뜬다** (실기기에서 실제로 났다).
/// 크게 보기에서는 늘려 보므로 안 준다.
Widget chatPhoto(
  String url, {
  double? width,
  int? cacheWidth,
  BoxFit fit = BoxFit.cover,
  ImageErrorWidgetBuilder? onError,
}) {
  Widget file(File source, {ImageErrorWidgetBuilder? onFail}) => Image.file(
    source,
    width: width,
    cacheWidth: cacheWidth,
    fit: fit,
    frameBuilder: _fadeIn,
    errorBuilder: onFail ?? onError,
  );

  // 아직 안 올라간 것 — 고르자마자 기기 원본을 그린다
  if (url.startsWith(localFilePrefix)) {
    return file(File(url.substring(localFilePrefix.length)));
  }

  // 방금 내가 올린 것 — 서버 주소로 바뀌어도 올린 파일 그대로 쓴다
  final mine = ChatStore.instance.localCopyOf(url);
  if (mine != null && File(mine).existsSync()) return file(File(mine));

  // 예전에 받아 둔 것 — 첫 프레임부터 뜬다 (흰 칸에서 튀어나오지 않는다)
  final saved = PhotoCache.ready(url);
  if (saved != null) return file(saved);

  return _FetchedPhoto(
    url: url,
    width: width,
    cacheWidth: cacheWidth,
    fit: fit,
    onError: onError,
  );
}

/// 받아오는 동안 흰 칸이었다가 툭 튀어나오지 않게 살짝 들여 보낸다
Widget _fadeIn(BuildContext _, Widget child, int? frame, bool alreadyThere) {
  if (alreadyThere) return child;
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: Duration(milliseconds: 200),
    curve: Curves.easeOut,
    child: child,
  );
}

/// 아직 안 받아 본 사진 — 받아서 **파일로 남긴 뒤** 그린다
///
/// 받는 동안은 옅은 회색 칸으로 자리를 지킨다. 다음부터는 [PhotoCache.ready]
/// 가 바로 찾아 줘서 이 위젯을 아예 안 거친다.
class _FetchedPhoto extends StatefulWidget {
  _FetchedPhoto({
    required this.url,
    required this.width,
    required this.cacheWidth,
    required this.fit,
    required this.onError,
  });

  final String url;
  final double? width;
  final int? cacheWidth;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? onError;

  @override
  State<_FetchedPhoto> createState() => _FetchedPhotoState();
}

class _FetchedPhotoState extends State<_FetchedPhoto> {
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    PhotoCache.fetch(widget.url).then((file) {
      if (!mounted) return;
      setState(() {
        _file = file;
        _failed = file == null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file != null) {
      return Image.file(
        file,
        width: widget.width,
        cacheWidth: widget.cacheWidth,
        fit: widget.fit,
        frameBuilder: _fadeIn,
        errorBuilder: widget.onError,
      );
    }
    // 못 받았으면 서버에서 바로 그려 본다 (거기서도 안 되면 부른 쪽이 정한다)
    if (_failed) {
      return Image.network(
        fileUrl(widget.url),
        width: widget.width,
        cacheWidth: widget.cacheWidth,
        fit: widget.fit,
        frameBuilder: _fadeIn,
        errorBuilder: widget.onError,
      );
    }
    // 받는 동안 — 흰 바탕이 아니라 옅은 회색으로 자리를 지킨다
    return Container(width: widget.width, color: AppColors.gray100);
  }
}
