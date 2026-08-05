import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../input/pressable.dart';
import '../../theme/app_shadows.dart';

/// 안드로이드 전용 하단바
///
/// iOS의 떠 있는 글래스 캡슐 대신, 평평한 바 가운데에 브랜드 그라데이션 원
/// ("전체")을 두고 좌우로 주요 탭을 배치한다. 가운데를 누르면 위쪽으로
/// 반원을 그리며 나머지 메뉴(근태·급여·공지·랭킹)가 펼쳐진다.
///
/// 인덱스는 MainShell의 `[..._mainPages, ..._subPages]` 순서를 따른다.
/// 0~3 = 홈·업무·프로젝트·회의록, 4~7 = 근태·월차·급여·공지·랭킹.
class AndroidTabBar extends StatefulWidget {
  AndroidTabBar({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  /// 바 높이 (화면 하단 여백 제외)
  static const double barHeight = 64;

  @override
  State<AndroidTabBar> createState() => _AndroidTabBarState();
}

class _AndroidTabBarState extends State<AndroidTabBar>
    with SingleTickerProviderStateMixin {
  // 항목이 하나씩 차례로 튀어나올 시간을 주려고 조금 길게 잡는다
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 420),
  );

  bool _open = false;

  /// (인덱스, 아이콘, 라벨) — 바에 놓이는 주요 탭
  static const _main = [
    (0, Icons.home_rounded, '홈'),
    (1, Icons.work_rounded, '업무'),
    (2, Icons.folder_rounded, '프로젝트'),
    (3, Icons.insert_drive_file_rounded, '회의록'),
  ];

  /// 반원으로 펼쳐지는 서브 메뉴 (왼쪽부터)
  static const _fan = [
    (4, Icons.schedule_rounded, '근태·월차'),
    (5, Icons.payments_rounded, '급여'),
    (6, Icons.campaign_rounded, '공지'),
    (7, Icons.emoji_events_rounded, '랭킹'),
  ];

  /// 반원의 반지름 — 전체 버튼 중심에서 서브 메뉴 중심까지
  static const double _radius = 124;

  /// 호 전체를 위로 띄우는 양.
  /// 이게 없으면 양 끝 항목(근태·랭킹)의 라벨이 하단바에 가린다.
  static const double _lift = 30;

  /// 항목 하나가 튀어나오는 데 걸리는 비율. 나머지는 시차로 쓴다.
  static const double _popSpan = 0.55;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _select(int index) {
    if (_open) _toggle();
    widget.onSelect(index);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // 화면 아래 끝에서 전체 버튼 중심까지의 거리
    final centerY = safeBottom + AndroidTabBar.barHeight / 2 + 6;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Stack(
        clipBehavior: Clip.none,
        children: [
          // 펼쳤을 때만 뒤를 덮는 딤 — 누르면 닫힌다
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_open,
              child: GestureDetector(
                onTap: _toggle,
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: 0.35 * _controller.value.clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
          ),
          for (var i = 0; i < _fan.length; i++)
            _fanItem(i, width: width, centerY: centerY),
          Align(alignment: Alignment.bottomCenter, child: _bar(safeBottom)),
        ],
      ),
    );
  }

  Widget _bar(double safeBottom) {
    return Container(
      padding: EdgeInsets.only(bottom: safeBottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.gray100)),
        boxShadow: [
          BoxShadow(
            color: AppShadows.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: AndroidTabBar.barHeight,
        child: Row(
          children: [
            Expanded(child: _barItem(_main[0])),
            Expanded(child: _barItem(_main[1])),
            // 가운데 전체 버튼은 바 위로 살짝 솟는다
            SizedBox(width: 76, child: Center(child: _centerButton())),
            Expanded(child: _barItem(_main[2])),
            Expanded(child: _barItem(_main[3])),
          ],
        ),
      ),
    );
  }

  Widget _barItem((int, IconData, String) item) {
    final (index, icon, label) = item;
    final selected = widget.index == index;

    return Pressable(
      scale: 0.92,
      onTap: () => _select(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 23,
            color: selected ? AppColors.primary : AppColors.gray400,
          ),
          SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: selected ? AppColors.primary : AppColors.gray500,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 브랜드 그라데이션 원 — 누르면 반원 메뉴가 펼쳐지고 X로 바뀐다
  Widget _centerButton() {
    return Pressable(
      scale: 0.92,
      onTap: _toggle,
      child: Transform.translate(
        offset: Offset(0, -10),
        child: Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Transform.rotate(
            // 펼쳐질 때 살짝 돌면서 X로 바뀐다
            angle: _controller.value * math.pi * 0.25,
            child: _controller.value > 0.5
                ? Icon(Icons.close_rounded, size: 24, color: Colors.white)
                : Text(
                    '전체',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _fanItem(int i, {required double width, required double centerY}) {
    final (index, icon, label) = _fan[i];
    final selected = widget.index == index;

    // 왼쪽부터 오른쪽으로 반원(180°→0°)에 고르게 배치한다
    final angle = math.pi - (i + 0.5) / _fan.length * math.pi;
    final dx = _radius * math.cos(angle);
    final dy = _radius * math.sin(angle) + _lift;

    const itemW = 74.0;
    const itemH = 76.0;

    // 왼쪽부터 하나씩 차례로 튀어나오고, 닫을 때는 오른쪽부터 사라진다.
    // (열 때는 뒤로 젖혔다 튀는 곡선, 닫을 때는 되감기는 곡선)
    final begin = i * (1 - _popSpan) / (_fan.length - 1);
    final t = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, begin + _popSpan, curve: Curves.easeOutBack),
      reverseCurve: Interval(begin, begin + _popSpan, curve: Curves.easeInBack),
    ).value;

    return Positioned(
      left: width / 2 + dx - itemW / 2,
      bottom: centerY + dy - itemH / 2,
      child: IgnorePointer(
        ignoring: !_open,
        child: Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: t.clamp(0.0, 1.5),
            child: SizedBox(
              width: itemW,
              height: itemH,
              child: Pressable(
                scale: 0.9,
                onTap: () => _select(index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      // 딤 위에 뜨는 흰 원. 지금 보고 있는 탭만 파랗게.
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppShadows.ink.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: selected ? Colors.white : AppColors.gray700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 1,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
