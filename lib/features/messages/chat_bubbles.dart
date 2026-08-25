part of 'chat_screen.dart';

class _RemovableMessage extends StatelessWidget {
  _RemovableMessage({
    super.key,
    required this.removing,
    required this.mine,
    required this.child,
  });

  final bool removing;
  final bool mine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: removing ? 0.0 : 1.0),
      duration: Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      builder: (context, t, child) => ClipRect(
        child: Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            heightFactor: t,
            child: Transform.scale(
              scale: 0.85 + 0.15 * t,
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: child,
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}

bool _photoOnly(String text, String? replyTo, List<String> attachments) =>
    text.isEmpty &&
    replyTo == null &&
    attachments.isNotEmpty &&
    attachments.every(isImageAttachment);

/// 첨부 — 사진은 격자로, 나머지는 파일 이름 한 줄
///
/// **여러 장이면 정사각으로 잘라 격자로 세운다.** 세로로 쌓으면 사진마다
/// 길이가 달라 줄이 들쭉날쭉해지고, 같은 크기로 맞추면 두 장이 위아래로
/// 늘어져 한 화면을 다 먹는다.
///
/// | 장수 | 모양 |
/// |---|---|
/// | 1 | 비율 그대로 (세로로 길면 [_maxSingle] 에서 자른다) |
/// | 2 · 4 | 두 칸씩 |
/// | 3 · 5 · 6 | 세 칸씩 |
/// | 7 이상 | 여섯 칸까지 세우고 마지막 칸에 `+N` |
class _Attachments extends StatelessWidget {
  _Attachments({
    required this.urls,
    required this.mine,
    required this.sender,
    required this.sentAt,
    this.bare = false,
    this.onDoubleTap,
    this.onLongPress,
  });

  final List<String> urls;
  final bool mine;

  /// 크게 보기 머리말에 쓸 보낸 사람·시각
  final String sender;
  final DateTime sentAt;

  /// 말풍선이 받던 손짓 — 사진 위에서도 그대로 되게 넘겨받는다.
  /// 안 넘기면 사진을 누르는 순간 더블탭 ❤️·길게누르기가 죽는다
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  /// 말풍선 밖에 놓였는지 — 실패했을 때 쓸 글자색이 갈린다
  /// (말풍선 안에서는 흰 글씨인데, 밖에서는 흰 배경이라 안 보인다)
  final bool bare;

  /// 격자·사진 한 장의 폭
  static const _width = 220.0;

  /// 칸 사이 틈
  static const _gap = 3.0;

  /// 세울 수 있는 최대 칸 수 (세 칸 × 두 줄) — 넘치면 마지막 칸이 `+N` 이 된다
  static const _maxTiles = 6;

  /// 한 장짜리 사진의 최대 높이 — 세로로 긴 사진이 화면을 다 먹지 않게
  static const _maxSingle = 280.0;

  /// 풀어 둘 가로 픽셀 — 화면 배율 3배까지 보고 넉넉하게 잡는다.
  /// 원본 그대로 풀면 캐시가 넘쳐 스크롤할 때마다 사진이 깜빡인다
  static const _cacheSingle = 660;
  static const _cacheTile = 330;

  Color get _tint => bare
      ? AppColors.textSecondary
      : (mine ? Colors.white : AppColors.textPrimary);

  @override
  Widget build(BuildContext context) {
    final photos = [
      for (final url in urls)
        if (isImageAttachment(url)) url,
    ];
    final files = [
      for (final url in urls)
        if (!isImageAttachment(url)) url,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (photos.length == 1)
          _open(context, photos, 0, _single(photos.first))
        else if (photos.length > 1)
          _grid(context, photos),
        for (var i = 0; i < files.length; i++) ...[
          if (i > 0 || photos.isNotEmpty) SizedBox(height: 6),
          _file(files[i], _tint),
        ],
      ],
    );
  }

  /// 눌러서 크게 보기 — 말풍선이 받던 손짓도 같이 얹는다
  Widget _open(
    BuildContext context,
    List<String> photos,
    int index,
    Widget child,
  ) => GestureDetector(
    onTap: () =>
        showPhotoViewer(context, photos, index, title: sender, time: sentAt),
    onDoubleTap: onDoubleTap,
    onLongPress: onLongPress,
    child: child,
  );

  /// 사진 비율을 아직 모를 때 잡아 둘 높이 — 가로 사진(4:3) 쯤으로 본다
  static const _unknownSingle = 165.0;

  /// 한 장 — 비율 그대로
  Widget _single(String url) =>
      _SinglePhoto(url: url, onError: (_, _, _) => _file(url, _tint));

  /// 여러 장 — 정사각으로 잘라 격자로
  ///
  /// 바깥 모서리만 둥글린다 (칸마다 둥글리면 틈이 도드라진다).
  Widget _grid(BuildContext context, List<String> photos) {
    final shown = photos.length > _maxTiles ? _maxTiles : photos.length;
    final columns = (shown == 2 || shown == 4) ? 2 : 3;
    final tile = (_width - _gap * (columns - 1)) / columns;
    final rows = (shown / columns).ceil();
    final rest = photos.length - shown;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: _width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) SizedBox(height: _gap),
              Row(
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) SizedBox(width: _gap),
                    SizedBox(
                      width: tile,
                      height: tile,
                      // 마지막 줄이 덜 찼으면 빈 자리로 둔다 (회색 칸을 안 그린다)
                      child: switch (row * columns + col) {
                        final i when i >= shown => null,
                        final i => _open(
                          context,
                          photos,
                          i,
                          _tile(
                            photos[i],
                            // 못 보여준 장수는 마지막 칸에 얹는다
                            more: i == shown - 1 && rest > 0 ? rest : 0,
                          ),
                        ),
                      },
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(String url, {required int more}) => Stack(
    fit: StackFit.expand,
    children: [
      // 사진이 오기 전 자리 — 흰 칸이 아니라 옅은 회색이라 덜 튄다
      ColoredBox(color: AppColors.gray100),
      chatPhoto(
        url,
        cacheWidth: _cacheTile,
        // 칸이 작아 파일 이름을 못 넣는다 — 자리는 남기고 아이콘만 둔다
        onError: (_, _, _) => ColoredBox(
          color: AppColors.gray100,
          child: Icon(CupertinoIcons.doc, size: 18, color: AppColors.gray400),
        ),
      ),
      if (more > 0)
        ColoredBox(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: Text(
              '+$more',
              style: AppTextStyles.body1.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _file(String url, Color tint) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(CupertinoIcons.doc, size: 15, color: tint),
      SizedBox(width: 6),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 200),
        child: Text(
          _nameOf(url),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body2.copyWith(color: tint),
        ),
      ),
    ],
  );

  /// `/files/2026/08/abc.png?exp=..` 에서 보여줄 이름만 뽑는다
  static String _nameOf(String url) {
    final path = url.split('?').first;
    return path.substring(path.lastIndexOf('/') + 1);
  }
}

/// 사진 한 장 — **자리를 먼저 잡고** 그린다
///
/// 예전에는 높이를 안 정하고 사진이 스스로 정하게 뒀다. 그러면 다 받아서
/// 풀기 전까지 **높이가 0** 이라, 사진이 뜨는 순간 말풍선이 확 늘어나면서
/// 목록이 통째로 밀린다 (2026-08-19).
///
/// - 방에 들어가면 바닥에 내려놨는데 사진이 뜨면서 **화면이 중간에 선다**
/// - 스크롤하면 사진이 하나씩 뜰 때마다 **목록이 흔들린다**
///
/// 대화방이 들어갈 때 1.5초 동안 바닥을 붙잡고 있는 것([_pinToBottom])도
/// 이걸 덮으려던 것이다.
///
/// 한 번 본 사진은 [PhotoCache] 가 비율을 들고 있어서 **받기 전에** 제 높이로
/// 자리를 잡는다 — 사진이 떠도 목록이 안 움직인다. 처음 보는 사진만
/// [_Attachments._unknownSingle] 로 잡아 두었다가 풀리는 순간 고쳐 잡는다.
///
/// **비율을 알 때 그려지는 모양은 예전과 같다** — 예전에도 폭 220 에 높이는
/// 비율대로였고 280 에서 잘렸다.
class _SinglePhoto extends StatefulWidget {
  _SinglePhoto({required this.url, required this.onError});

  final String url;
  final ImageErrorWidgetBuilder onError;

  @override
  State<_SinglePhoto> createState() => _SinglePhotoState();
}

class _SinglePhotoState extends State<_SinglePhoto> {
  double? _ratio;
  String? _key;

  /// 이 폭에서 이 비율이면 몇 픽셀인가 — 280 을 넘으면 예전처럼 잘라 보여준다
  double get _height {
    final ratio = _ratio;
    if (ratio == null) return _Attachments._unknownSingle;
    final natural = _Attachments._width / ratio;
    return natural > _Attachments._maxSingle
        ? _Attachments._maxSingle
        : natural;
  }

  @override
  Widget build(BuildContext context) {
    // 서명이 갈려도 같은 사진이면 다시 안 묻는다
    final key = PhotoCache.keyOf(widget.url);
    if (key != _key) {
      _key = key;
      _ratio = PhotoCache.ratioOf(widget.url);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: _Attachments._width,
        height: _height,
        child: chatPhoto(
          widget.url,
          width: _Attachments._width,
          cacheWidth: _Attachments._cacheSingle,
          // 못 받아오면(서명 만료 등) 파일 줄로 떨어진다
          onError: widget.onError,
          // 재는 사이에 이 자리가 다른 사진으로 바뀌었으면 버린다
          // (`ListView` 가 자리를 물려주면 한 State 가 여러 사진을 그린다)
          onRatio: (ratio) {
            if (!mounted || _key != key || ratio == _ratio) return;
            setState(() => _ratio = ratio);
          },
        ),
      ),
    );
  }
}

class _MyBubble extends StatelessWidget {
  _MyBubble({
    required this.text,
    required this.sender,
    required this.sentAt,
    required this.timeLabel,
    required this.showTime,
    this.attachments = const [],
    this.replyTo,
    this.reaction,
    this.pending = false,
    this.onDoubleTap,
    this.onLongPress,
    this.actions,
  });

  final String text;

  /// 사진 크게 보기 머리말에 쓴다 (보낸 사람·시각)
  final String sender;
  final DateTime sentAt;
  final String timeLabel;
  final bool showTime;

  final List<String> attachments;
  final String? replyTo;
  final String? reaction;

  /// 아직 서버 응답을 못 받았다 — 살짝 흐리게 그려 보내는 중임을 알린다
  final bool pending;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  /// PC 호버 액션 아이콘 (말풍선 왼쪽에 붙는다)
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (actions != null) ...[actions!, SizedBox(width: 4)],
          if (showTime) ...[
            Text(
              timeLabel,
              style: AppTextStyles.caption.copyWith(fontSize: 10),
            ),
            SizedBox(width: 6),
          ],
          Flexible(child: _bubble()),
        ],
      ),
    );
  }

  Widget _bubble() {
    return Opacity(
      // 보내는 중에는 살짝 흐리다 — 서버가 받으면 또렷해진다
      opacity: pending ? 0.55 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress,
            // 사진만 보냈으면 말풍선 없이 그림만 (더블탭·길게누르기는 그대로)
            child: _photoOnly(text, replyTo, attachments)
                ? _Attachments(
                    urls: attachments,
                    mine: true,
                    sender: sender,
                    sentAt: sentAt,
                    bare: true,
                    onDoubleTap: onDoubleTap,
                    onLongPress: onLongPress,
                  )
                : Container(
                    constraints: BoxConstraints(maxWidth: 280),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(6),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (replyTo != null)
                          Container(
                            margin: EdgeInsets.only(bottom: 6),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              replyTo!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        // 상대 말풍선과 같은 차례 — 첨부가 위, 글이 아래.
                        // 여기가 빠져 있어서 **내가 보낸 사진이 빈 말풍선으로** 떴다
                        // (받는 쪽에서는 보였다). 본문이 없으면 글줄도 안 그린다
                        if (attachments.isNotEmpty)
                          _Attachments(
                            urls: attachments,
                            mine: true,
                            sender: sender,
                            sentAt: sentAt,
                            onDoubleTap: onDoubleTap,
                            onLongPress: onLongPress,
                          ),
                        if (text.isNotEmpty) ...[
                          if (attachments.isNotEmpty) SizedBox(height: 6),
                          Text(
                            text,
                            style: AppTextStyles.body2.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          if (reaction != null)
            Positioned(
              bottom: -14,
              right: 10,
              child: _ReactionPill(
                key: ValueKey(reaction!),
                emoji: reaction!,
                onTap: onLongPress,
              ),
            ),
        ],
      ),
    );
  }
}

class _TheirBubble extends StatelessWidget {
  _TheirBubble({
    required this.name,
    required this.sentAt,
    required this.color,
    required this.text,
    required this.timeLabel,
    required this.showProfile,
    required this.showTime,
    this.attachments = const [],
    this.emoji,
    this.replyTo,
    this.reaction,
    this.onDoubleTap,
    this.onLongPress,
    this.actions,
  });

  final String name;

  /// 사진 크게 보기 머리말에 쓴다 (보낸 시각)
  final DateTime sentAt;

  final Color color;
  final String? emoji;
  final String text;
  final String timeLabel;
  final bool showProfile;
  final bool showTime;
  final List<String> attachments;
  final String? replyTo;
  final String? reaction;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  /// PC 호버 액션 아이콘 (말풍선 오른쪽에 붙는다)
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 프로필이 뜨는 줄은 최소 40 — 짧은 말풍선에서 동그라미가 삐져나오지 않게
            SizedBox(width: 48, height: showProfile ? 40 : 0),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showProfile)
                    Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onDoubleTap: onDoubleTap,
                        onLongPress: onLongPress,
                        // 사진만 왔으면 말풍선 없이 그림만 (내 쪽과 같은 기준)
                        child: _photoOnly(text, replyTo, attachments)
                            ? _Attachments(
                                urls: attachments,
                                mine: false,
                                sender: name,
                                sentAt: sentAt,
                                bare: true,
                                onDoubleTap: onDoubleTap,
                                onLongPress: onLongPress,
                              )
                            : Container(
                                constraints: BoxConstraints(maxWidth: 260),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gray50,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(20),
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (replyTo != null)
                                      Container(
                                        margin: EdgeInsets.only(bottom: 6),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.gray100,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          replyTo!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.caption,
                                        ),
                                      ),
                                    if (attachments.isNotEmpty)
                                      _Attachments(
                                        urls: attachments,
                                        mine: false,
                                        sender: name,
                                        sentAt: sentAt,
                                        onDoubleTap: onDoubleTap,
                                        onLongPress: onLongPress,
                                      ),
                                    if (text.isNotEmpty) ...[
                                      if (attachments.isNotEmpty)
                                        SizedBox(height: 6),
                                      Text(text, style: AppTextStyles.body2),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                      if (reaction != null)
                        Positioned(
                          bottom: -14,
                          left: 10,
                          child: _ReactionPill(
                            key: ValueKey(reaction!),
                            emoji: reaction!,
                            onTap: onLongPress,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (showTime) ...[
              SizedBox(width: 6),
              Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  timeLabel,
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
              ),
            ],
            if (actions != null) ...[SizedBox(width: 4), actions!],
          ],
        ),
        if (showProfile)
          Positioned(
            left: 0,
            top: 0,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: emoji != null ? 0.12 : 1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  emoji ?? name.characters.first,
                  style: emoji != null
                      ? TextStyle(fontSize: 17)
                      : TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
