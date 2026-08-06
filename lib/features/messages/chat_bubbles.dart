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

/// 말풍선 안의 첨부 — 사진이면 미리보기, 아니면 파일 이름 한 줄
///
/// **말풍선 밖에 새로 그리는 것이 없다.** 본문 글자가 들어가던 자리에
/// 같은 폭으로 들어간다.
class _Attachments extends StatelessWidget {
  _Attachments({required this.urls, required this.mine});

  final List<String> urls;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final tint = mine ? Colors.white : AppColors.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final url in urls)
          Padding(
            padding: EdgeInsets.only(bottom: url == urls.last ? 0 : 6),
            child: isImageAttachment(url)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      fileUrl(url),
                      width: 200,
                      fit: BoxFit.cover,
                      // 못 받아오면(서명 만료 등) 파일 줄로 떨어진다
                      errorBuilder: (_, _, _) => _file(url, tint),
                    ),
                  )
                : _file(url, tint),
          ),
      ],
    );
  }

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
            child: Container(
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
                      style: AppTextStyles.body2.copyWith(color: Colors.white),
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
                child: Container(
                  constraints: BoxConstraints(maxWidth: 260),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
