import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/staff/staff_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/util/photo.dart';
import '../../core/util/photo_cache.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/glass/glass_icon_button.dart';
import '../../core/widgets/glass/top_frost.dart';
import '../../core/widgets/input/pressable.dart';
import '../auth/auth_session.dart';
import '../auth/logout.dart';
part 'profile_summary.dart';
part 'profile_basic.dart';
part 'profile_status.dart';
part 'profile_theme.dart';
part 'profile_account.dart';
part 'profile_widgets.dart';

/// 내 프로필 화면
///
/// 내가 바꿀 수 있는 것만 모은 자리다 — 이름·프로필 사진·아바타 색·업무 상태·
/// 비밀번호. 직군·권한·지점은 관리자가 정하는 값이라 읽기만 한다
/// (**이메일은 2026-08-19 부터 본인이 바꾼다**).
///
/// 바꾼 값은 [currentUser] 에 바로 반영한다. 사이드바·아바타가 그 값을 읽어서,
/// 안 갈아끼우면 옛 이름·색이 남는다.
class ProfileScreen extends StatefulWidget {
  ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scrollController = ScrollController();

  /// 0(펼침) ~ 1(접힘). 스크롤에 따른 상단 블러 강도.
  final _collapse = ScrollCollapse();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _reload();
  }

  /// 열 때 한 번 다시 받는다 — 다른 기기에서 바꿨을 수 있다.
  /// 실패해도 화면은 로그인 때 받아 둔 값으로 뜬다
  Future<void> _reload() async {
    try {
      applyCurrentUser(await StaffApi.me());
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _onScroll() => _collapse.update(_scrollController.offset);

  @override
  void dispose() {
    _scrollController.dispose();
    _collapse.dispose();
    super.dispose();
  }

  /// 프로필 요약 아래로 이어지는 설정 카드들 (폰·PC 공통)
  ///
  /// 바뀐 게 있으면 화면 전체를 다시 그린다 — 요약 카드가 같은 값을 읽는다
  List<Widget> get _settingCards => [
    _BasicInfoCard(onChanged: () => setState(() {})),
    SizedBox(height: 16),
    _WorkStatusCard(onChanged: () => setState(() {})),
    SizedBox(height: 16),
    _ThemeCard(),
    SizedBox(height: 16),
    _PasswordCard(),
    SizedBox(height: 16),
    // 되돌릴 수 있는 것(로그아웃) 다음에 되돌릴 수 없는 것(탈퇴)
    _LogoutCard(),
    SizedBox(height: 16),
    _WithdrawCard(),
  ];

  @override
  Widget build(BuildContext context) {
    return isDesktop ? _buildDesktop() : _buildMobile();
  }

  /// 데스크톱: 왼쪽에 프로필 요약을 두고 오른쪽 설정만 스크롤한다.
  /// 요약 카드는 스크롤 영역 밖이라 스크롤해도 제자리에 남는다.
  Widget _buildDesktop() {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(28, 68, 20, 0),
                  child: SizedBox(width: 320, child: _ProfileSummaryCard()),
                ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(0, 68, 28, 40),
                    children: _settingCards,
                  ),
                ),
              ],
            ),
          ),
          TopFrost(collapse: _collapse, color: AppColors.background),
          // 상단 중앙 고정 타이틀 (터치는 아래 리스트로 통과)
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text('내 프로필', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
          // 좌측 상단 고정 뒤로가기 글래스 버튼
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(20, 68, 20, 40),
              children: [
                _ProfileSummaryCard(),
                SizedBox(height: 16),
                ..._settingCards,
              ],
            ),
          ),
          TopFrost(collapse: _collapse, color: AppColors.background),
          // 상단 중앙 고정 타이틀 (터치는 아래 리스트로 통과)
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text('내 프로필', style: AppTextStyles.title3),
                ),
              ),
            ),
          ),
          // 좌측 상단 고정 뒤로가기 글래스 버튼
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: GlassIconButton(
                symbol: 'chevron.backward',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
