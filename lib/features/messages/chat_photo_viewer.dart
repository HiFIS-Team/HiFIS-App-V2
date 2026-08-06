part of 'chat_screen.dart';

// ── 사진 크게 보기 ──

/// 사진을 눌렀을 때 — 검은 화면에 한 장씩, 좌우로 넘긴다
///
/// - **아래로 끌어내리면 닫힌다.** 끌어내리는 만큼 배경이 옅어져서 뒤 대화가 비친다
/// - 손가락 두 개로 늘려 볼 수 있고, **늘린 상태에서는 넘기기·끌어내리기가 안 걸린다**
///   (사진을 옮기려는 손짓과 겹친다)
/// - 여러 장이면 위에 `2 / 5` 가 뜬다
void showPhotoViewer(BuildContext context, List<String> urls, int index) {
  Navigator.push<void>(
    context,
    PageRouteBuilder<void>(
      // 끌어내릴 때 뒤 대화가 비쳐야 해서 불투명 라우트로 두지 않는다
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: 220),
      reverseTransitionDuration: Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => _PhotoViewer(urls: urls, index: index),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  _PhotoViewer({required this.urls, required this.index});

  final List<String> urls;
  final int index;

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

  void _onDragEnd(DragEndDetails details) {
    final fast = (details.primaryVelocity ?? 0).abs() > 700;
    if (_drag.abs() > _dismissAt || fast) {
      Navigator.pop(context);
      return;
    }
    setState(() => _drag = 0);
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.urls.length > 1;

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
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(top: 4, left: 8, right: 8),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: CupertinoIcons.xmark,
                    onTap: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: many
                          ? Text(
                              '${_at + 1} / ${widget.urls.length}',
                              style: AppTextStyles.body2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : SizedBox.shrink(),
                    ),
                  ),
                  // 가운데 숫자가 진짜 가운데 오게 왼쪽 버튼만큼 자리를 비운다
                  SizedBox(width: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 검은 화면 위 동그란 버튼 — 밝은 사진 위에서도 보이게 반투명 검정을 깐다
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

/// 사내톡 사진 한 장 — 서버 주소든 아직 안 올라간 기기 파일이든 같이 다룬다
///
/// 보내는 중에는 기기 안 파일을 미리 그린다 ([localFilePrefix]).
Widget chatPhoto(
  String url, {
  double? width,
  BoxFit fit = BoxFit.cover,
  ImageErrorWidgetBuilder? onError,
}) {
  if (url.startsWith(localFilePrefix)) {
    return Image.file(
      File(url.substring(localFilePrefix.length)),
      width: width,
      fit: fit,
      errorBuilder: onError,
    );
  }
  return Image.network(
    fileUrl(url),
    width: width,
    fit: fit,
    errorBuilder: onError,
  );
}
