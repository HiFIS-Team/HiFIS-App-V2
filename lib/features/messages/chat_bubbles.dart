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

/// 사진만 보낸 메시지인지 — 그러면 **말풍선을 안 씌운다**
///
/// 사진은 대개 말풍선 없이 그림만 보내는 것이라 그 결로 맞췄다.
/// 글이 같이 있거나, 답글 인용이 붙었거나, 사진이 아닌 파일이 섞였으면
/// 예전처럼 말풍선 안에 담는다 — 담을 것이 그림만이 아니기 때문이다.
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
  _Attachments({required this.urls, required this.mine, this.bare = false});

  final List<String> urls;
  final bool mine;

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
          _single(photos.first)
        else if (photos.length > 1)
          _grid(photos),
        for (var i = 0; i < files.length; i++) ...[
          if (i > 0 || photos.isNotEmpty) SizedBox(height: 6),
          _file(files[i], _tint),
        ],
      ],
    );
  }

  /// 한 장 — 비율 그대로
  Widget _single(String url) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: _maxSingle),
      child: Image.network(
        fileUrl(url),
        width: _width,
        fit: BoxFit.cover,
        // 못 받아오면(서명 만료 등) 파일 줄로 떨어진다
        errorBuilder: (_, _, _) => _file(url, _tint),
      ),
    ),
  );

  /// 여러 장 — 정사각으로 잘라 격자로
  ///
  /// 바깥 모서리만 둥글린다 (칸마다 둥글리면 틈이 도드라진다).
  Widget _grid(List<String> photos) {
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
                        final i => _tile(
                          photos[i],
                          // 못 보여준 장수는 마지막 칸에 얹는다
                          more: i == shown - 1 && rest > 0 ? rest : 0,
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
      Image.network(
        fileUrl(url),
        fit: BoxFit.cover,
        // 칸이 작아 파일 이름을 못 넣는다 — 자리는 남기고 아이콘만 둔다
        errorBuilder: (_, _, _) => ColoredBox(
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

class _MyBubble extends StatelessWidget {
  _MyBubble({
    required this.text,
    this.attachments = const [],
    this.replyTo,
    this.reaction,
    this.pending = false,
    this.onDoubleTap,
    this.onLongPress,
    this.actions,
  });

  final String text;
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
        mainAxisSize: MainAxisSize.min,
        children: [
          if (actions != null) ...[actions!, SizedBox(width: 4)],
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
                ? _Attachments(urls: attachments, mine: true, bare: true)
                : Container(
                    constraints: BoxConstraints(maxWidth: 280),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(6),
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
                          _Attachments(urls: attachments, mine: true),
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
    required this.color,
    required this.text,
    this.attachments = const [],
    this.emoji,
    this.replyTo,
    this.reaction,
    this.onDoubleTap,
    this.onLongPress,
    this.actions,
  });

  final String name;
  final Color color;
  final String? emoji;
  final String text;
  final List<String> attachments;
  final String? replyTo;
  final String? reaction;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  /// PC 호버 액션 아이콘 (말풍선 오른쪽에 붙는다)
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: emoji != null ? 0.12 : 1),
            shape: BoxShape.circle,
          ),
          child: Text(
            emoji ?? name.characters.first,
            style: emoji != null
                ? TextStyle(fontSize: 12)
                : TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
          ),
        ),
        SizedBox(width: 8),
        Flexible(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onDoubleTap: onDoubleTap,
                onLongPress: onLongPress,
                // 사진만 왔으면 말풍선 없이 그림만 (내 쪽과 같은 기준)
                child: _photoOnly(text, replyTo, attachments)
                    ? _Attachments(urls: attachments, mine: false, bare: true)
                    : Container(
                        constraints: BoxConstraints(maxWidth: 260),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                            bottomLeft: Radius.circular(6),
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
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  replyTo!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption,
                                ),
                              ),
                            if (attachments.isNotEmpty)
                              _Attachments(urls: attachments, mine: false),
                            if (text.isNotEmpty) ...[
                              if (attachments.isNotEmpty) SizedBox(height: 6),
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
        ),
        if (actions != null) ...[SizedBox(width: 4), actions!],
      ],
    );
  }
}
