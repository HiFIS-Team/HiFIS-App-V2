import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_shadows.dart';

/// 화면 아래 떠 있는 글래스 입력바 — 사내톡과 프로젝트 댓글이 같이 쓴다
///
/// 반투명 면 + 블러로 뒤 콘텐츠가 비쳐 지나가고, 글자를 넣으면 오른쪽 아이콘이
/// 파란 전송 버튼으로 바뀐다. 전송 후에도 포커스를 되돌려 연달아 쓸 수 있다.
class GlassInputBar extends StatefulWidget {
  GlassInputBar({
    super.key,
    required this.onSend,
    this.focusNode,
    this.hint = '메시지 보내기',
    this.autofocus = false,
    this.replyLabel,
    this.onCancelReply,
    this.onChanged,
    this.onAttach,
  });

  final ValueChanged<String> onSend;
  final FocusNode? focusNode;
  final String hint;
  final bool autofocus;

  /// 답글 대상 원문. 있으면 입력바 위에 인용 줄이 표시된다.
  final String? replyLabel;
  final VoidCallback? onCancelReply;

  /// 글자가 바뀔 때마다 — 사내톡의 '입력 중' 신호에 쓴다
  final ValueChanged<String>? onChanged;

  /// 링크(클립) 아이콘을 눌렀을 때 — 없으면 눌러도 아무 일도 안 한다
  final VoidCallback? onAttach;

  @override
  State<GlassInputBar> createState() => _GlassInputBarState();
}

class _GlassInputBarState extends State<GlassInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
      widget.onChanged?.call(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    // 엔터/전송 후 포커스가 풀리므로 다시 잡아 연속 입력이 되게 한다
    widget.focusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.float,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: EdgeInsets.only(left: 18, right: 8),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
              // 네이티브 글래스의 림처럼 보이는 헤어라인 — 흰 배경에서도 구분되게
              border: Border.all(color: AppColors.gray100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 답글 인용 줄
                if (widget.replyLabel != null)
                  Padding(
                    padding: EdgeInsets.only(top: 12, right: 10),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.arrowshape_turn_up_left,
                          size: 14,
                          color: AppColors.gray500,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.replyLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onCancelReply,
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 16,
                            color: AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: widget.focusNode,
                          autofocus: widget.autofocus,
                          style: AppTextStyles.body2,
                          cursorColor: AppColors.primary,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: widget.hint,
                            hintStyle: AppTextStyles.body2.copyWith(
                              color: AppColors.gray400,
                            ),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // 입력 전에는 링크 아이콘, 입력 중에는 파란 전송(비행기) 버튼
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: _hasText
                            ? GestureDetector(
                                key: ValueKey('send'),
                                onTap: _submit,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.paperplane_fill,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              )
                            : GestureDetector(
                                key: ValueKey('link'),
                                onTap: widget.onAttach ?? () {},
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  color: Colors.transparent,
                                  child: Icon(
                                    CupertinoIcons.link,
                                    color: AppColors.gray600,
                                    size: 22,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
