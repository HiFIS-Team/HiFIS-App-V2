import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../util/sf_symbols.dart';
import 'pressable.dart';

/// 화면 아래 고정 버튼 — 바깥 여백 없이 버튼만 그린다
///
/// 애플은 네이티브 리퀴드 글래스(CNButton)를 쓰고, 글래스가 없는
/// 안드로이드는 **반투명이 아니라 또렷한 단색**으로 대체한다.
/// (반투명 + 블러로 두면 뒤 콘텐츠에 묻혀 버튼이 안 보인다.)
class BottomActionButton extends StatelessWidget {
  BottomActionButton({
    super.key,
    required this.id,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.tinted = true,
    this.shrinkWrap = false,
  });

  /// 테마가 바뀔 때 네이티브 버튼을 새로 만들기 위한 식별자
  final String id;

  final String label;
  final VoidCallback onPressed;

  /// 조건이 갖춰져 눌러도 되는 상태면 true — 파랗게 채운다.
  ///
  /// 비활성화(enabled: false)하면 iOS가 글래스 재질을 빼버리므로 누르는 것
  /// 자체는 막지 않고, 조건 검사는 동작 쪽에서 해서 안내를 띄운다.
  final bool filled;

  /// 포인트 컬러를 입힐지 (취소처럼 중립적인 버튼은 false)
  final bool tinted;

  /// true면 글자 폭만큼만 차지한다 (취소 버튼처럼 옆에 붙일 때)
  final bool shrinkWrap;

  /// 탭바와 같은 높이
  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    if (isApple) {
      return CNButton(
        // 테마 전환 시 설정 유실 버그 회피용 재생성 키
        key: ValueKey('$id-${AppColors.isDark}'),
        label: label,
        style: filled ? CNButtonStyle.prominentGlass : CNButtonStyle.glass,
        tint: tinted ? AppColors.primary : null,
        height: height,
        shrinkWrap: shrinkWrap,
        onPressed: onPressed,
      );
    }
    return _solid();
  }

  /// 안드로이드 — 단색 알약. 배경이 흰 카드든 회색 화면이든 또렷하게 보인다.
  Widget _solid() {
    final Color background;
    final Color foreground;
    final Color border;
    if (filled) {
      background = AppColors.primary;
      foreground = Colors.white;
      border = Colors.transparent;
    } else if (tinted) {
      // 아직 조건이 안 갖춰진 상태 — 눌리는 자리라는 건 보이게 둔다
      background = AppColors.gray200;
      foreground = AppColors.gray700;
      border = Colors.transparent;
    } else {
      // 취소처럼 중립적인 버튼
      background = AppColors.surface;
      foreground = AppColors.textPrimary;
      border = AppColors.gray200;
    }

    final button = Pressable(
      onTap: onPressed,
      scale: 0.97,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: shrinkWrap ? EdgeInsets.symmetric(horizontal: 24) : null,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: border),
          boxShadow: [
            // 스크롤되는 콘텐츠 위에 떠 있어서 경계가 필요하다
            BoxShadow(
              color: Colors.black.withValues(alpha: filled ? 0.16 : 0.08),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: AppTextStyles.body1.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return shrinkWrap ? IntrinsicWidth(child: button) : button;
  }
}

/// 화면 아래에 떠 있는 하단 CTA 한 개 (여백·SafeArea까지 포함)
///
/// 하단 탭바와 같은 자리·높이에 놓여서, 탭바가 없는 화면(새로 만들기 등)에서
/// 주요 동작을 그 자리에 그대로 이어받는다.
class GlassBottomButton extends StatelessWidget {
  GlassBottomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.active = true,
  });

  final String label;
  final VoidCallback onPressed;

  /// 조건이 갖춰지면 파랗게 채운다
  final bool active;

  /// 탭바와 같은 높이
  static const double height = BottomActionButton.height;

  /// 스크롤 콘텐츠가 버튼에 가리지 않도록 아래에 남겨야 할 여백
  static double inset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + height + 34;

  @override
  Widget build(BuildContext context) {
    return BottomActionBar(
      children: [
        Expanded(
          child: BottomActionButton(
            id: 'glass-cta-$label',
            label: label,
            filled: active,
            onPressed: onPressed,
          ),
        ),
      ],
    );
  }
}

/// 하단 고정 버튼 줄 — SafeArea와 좌우 여백을 맞춰준다
///
/// 버튼이 하나든 둘(취소 + 확인)이든 같은 자리에 놓이도록 한 곳에서 감싼다.
class BottomActionBar extends StatelessWidget {
  BottomActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(children: children),
      ),
    );
  }
}
