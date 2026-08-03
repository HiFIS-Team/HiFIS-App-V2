import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/staff_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/employee.dart';
import '../../core/data/staff.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/top_frost.dart';
import '../auth/auth_session.dart';
import '../auth/logout.dart';

/// 내 프로필 화면
///
/// 내가 바꿀 수 있는 것만 모은 자리다 — 이름·프로필 사진·아바타 색·업무 상태·
/// 비밀번호. 직급·권한·지점·이메일은 관리자가 정하는 값이라 읽기만 한다.
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

// ---------------------------------------------------------------------------
// 프로필 요약
// ---------------------------------------------------------------------------

class _ProfileSummaryCard extends StatelessWidget {
  _ProfileSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // 데스크톱에서 스크롤 밖에 놓이면 세로로 늘어나므로 내용만큼만 차지한다
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Avatar(size: 56),
              SizedBox(width: 16),
              // 이름이 길면 이메일과 함께 카드 밖으로 넘친다
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title2,
                    ),
                    SizedBox(height: 2),
                    Text(
                      currentUser?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(),
          ),
          Row(
            children: [
              Expanded(
                child: _SummaryField(
                  label: '사번',
                  value: currentUser?.empNo ?? '-',
                ),
              ),
              Expanded(
                child: _SummaryField(
                  label: '직급',
                  value: currentUser?.rank.label ?? '-',
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                // 팀은 관리자가 넣어 주는 값이라 비어 있을 수 있다
                child: _SummaryField(
                  label: '팀',
                  value: currentUser?.team ?? '-',
                ),
              ),
              Expanded(
                child: _SummaryField(
                  label: '권한',
                  value: currentUser?.role.label ?? '-',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryField extends StatelessWidget {
  _SummaryField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// 내 아바타 — 사진이 있으면 사진, 없으면 아바타 색 + 이름 첫 글자
class _Avatar extends StatelessWidget {
  _Avatar({required this.size, this.color});

  final double size;

  /// 색 고르는 자리에서 미리보기로 쓸 때만 넘긴다. 없으면 지금 내 색
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    final url = user?.avatarImageUrl;
    final fill = color ?? user?.color ?? AppColors.primary;
    final initial = me.isEmpty ? '·' : me.characters.first;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: url == null
          ? Text(
              initial,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            )
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // 서명이 만료됐거나 못 받으면 색 아바타로 떨어진다
              errorBuilder: (_, _, _) => Text(
                initial,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// 기본 정보
// ---------------------------------------------------------------------------

class _BasicInfoCard extends StatefulWidget {
  _BasicInfoCard({required this.onChanged});

  /// 이름·색이 바뀌면 요약 카드도 같이 다시 그린다
  final VoidCallback onChanged;

  @override
  State<_BasicInfoCard> createState() => _BasicInfoCardState();
}

class _BasicInfoCardState extends State<_BasicInfoCard> {
  static const _avatarColors = [
    Color(0xFF2F54EB),
    Color(0xFF2B6BF3),
    Color(0xFF5A6ACF),
    Color(0xFF3FA7E8),
    Color(0xFF3E8FA8),
    Color(0xFF3EBFA5),
    Color(0xFF3FA85C),
    Color(0xFF7CA83E),
    Color(0xFFC7952F),
    Color(0xFFD07E2C),
    Color(0xFFE0662B),
    Color(0xFFCC3B33),
    Color(0xFFD03A78),
    Color(0xFFBE3ACD),
    Color(0xFF8E3AD0),
    Color(0xFF6B3AD0),
    Color(0xFF3E4A5C),
    Color(0xFF64748B),
  ];

  late final _name = TextEditingController(text: me);
  late final _phone = TextEditingController(text: currentUser?.phone ?? '');

  /// 고른 아바타 색. **null 이면 아직 안 골랐다는 뜻**이다.
  ///
  /// 서버 색이 이 팔레트에 없을 수 있다 — 지금 명단 16명이 전부 그렇다
  /// (`#6366f1` 등, backend-gap.md 14번). 못 찾았다고 0번을 고른 것처럼 두면
  /// **이름만 바꾸려고 저장을 눌러도 색이 몰래 바뀐다.**
  late int? _selectedColor = _indexOfMyColor();

  bool _saving = false;
  bool _uploading = false;

  int? _indexOfMyColor() {
    final mine = currentUser?.color;
    if (mine == null) return null;
    final index = _avatarColors.indexWhere(
      (c) => c.toARGB32() == mine.toARGB32(),
    );
    return index < 0 ? null : index;
  }

  /// 미리보기에 쓸 색 — 아직 안 골랐으면 지금 내 색 그대로
  Color? get _previewColor {
    final index = _selectedColor;
    return index == null ? null : _avatarColors[index];
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppToast.show(context, '이름을 입력해주세요');
      return;
    }
    // 비워 두는 건 괜찮다 — 적었으면 제대로 적어야 한다
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (phone.isNotEmpty && (phone.length != 11 || !phone.startsWith('01'))) {
      AppToast.show(context, '휴대폰 번호 11자리를 입력해주세요');
      return;
    }
    setState(() => _saving = true);
    try {
      final picked = _previewColor;
      applyCurrentUser(
        await StaffApi.updateMe(
          name: name,
          phone: phone,
          // 안 골랐으면 안 보낸다 — 서버가 쓰던 색을 그대로 둔다
          avatarColor: picked == null ? null : _hexOf(picked),
        ),
      );
      if (!mounted) return;
      widget.onChanged();
      AppToast.show(context, '기본 정보를 저장했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _saving = false);
  }

  /// 프로필 사진 고르기 — 서버가 png·jpg·gif·webp 만 받는다
  Future<void> _pickImage() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: '프로필 사진 선택',
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp'],
    );
    final file = picked?.files.singleOrNull;
    final path = file?.path;
    if (file == null || path == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      applyCurrentUser(await StaffApi.uploadAvatar(path, filename: file.name));
      if (!mounted) return;
      widget.onChanged();
      AppToast.show(context, '프로필 사진을 올렸어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('기본 정보', style: AppTextStyles.title3),
          SizedBox(height: 20),
          _FieldLabel('이름'),
          SizedBox(height: 8),
          _InputBox(controller: _name),
          SizedBox(height: 20),
          _FieldLabel('전화번호'),
          SizedBox(height: 8),
          _InputBox(
            controller: _phone,
            hint: '01012345678',
            keyboardType: TextInputType.phone,
            helper: '조직도에서 서로 연락할 때 쓰여요.',
          ),
          SizedBox(height: 20),
          _FieldLabel('프로필 이미지'),
          SizedBox(height: 10),
          Row(
            children: [
              _Avatar(size: 56, color: _previewColor),
              SizedBox(width: 14),
              Pressable(
                onTap: _uploading ? () {} : _pickImage,
                scale: 0.94,
                child: Container(
                  height: 48,
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      _uploading ? '올리는 중…' : '이미지 업로드',
                      style: AppTextStyles.label.copyWith(
                        color: _uploading
                            ? AppColors.gray400
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            // 서버가 5MB 까지만 받는다 (`save_avatar`) — 한동안 10MB 라고 적혀 있었다
            '이미지가 없을 땐 아래 아바타 색과 이름 첫 글자로 표시됩니다. (5MB 이하)',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 20),
          Row(
            children: [
              _FieldLabel('아바타 색'),
              // 지금 색이 팔레트 밖이면 아무 칸에도 체크가 없어서 왜 그런지 안 보인다
              if (_selectedColor == null) ...[
                SizedBox(width: 8),
                Text('고르면 바뀌어요', style: AppTextStyles.caption),
              ],
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _avatarColors.length; i++)
                Pressable(
                  onTap: () => setState(() => _selectedColor = i),
                  scale: 0.88,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _avatarColors[i],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: i == _selectedColor
                        ? Icon(
                            CupertinoIcons.checkmark,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          SizedBox(height: 20),
          _FieldLabel('이메일'),
          SizedBox(height: 8),
          _InputBox(
            value: currentUser?.email ?? '',
            enabled: false,
            helper: '이메일은 관리자만 변경할 수 있습니다.',
          ),
          SizedBox(height: 20),
          _FieldLabel('사번'),
          SizedBox(height: 8),
          _InputBox(
            value: currentUser?.empNo ?? '-',
            enabled: false,
            helper: '가입 시 자동으로 부여됩니다.',
          ),
          SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: _SmallPrimaryButton(
              label: '저장',
              busy: _saving,
              onTap: _save,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 업무 상태
// ---------------------------------------------------------------------------

class _WorkStatusCard extends StatefulWidget {
  _WorkStatusCard({required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<_WorkStatusCard> createState() => _WorkStatusCardState();
}

class _WorkStatusCardState extends State<_WorkStatusCard> {
  static const _statuses = WorkStatus.values;

  late WorkStatus _selected = currentUser?.workStatus ?? WorkStatus.auto;
  late final _message = TextEditingController(
    text: currentUser?.statusMessage ?? '',
  );

  bool _saving = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  /// 상태와 메시지를 같이 올린다 — 칩만 누르고 저장을 안 하면 안 바뀐다
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      applyCurrentUser(
        await StaffApi.updateMe(
          workStatus: _selected,
          // 비운 것도 넘겨야 지워진다
          statusMessage: _message.text.trim(),
        ),
      );
      if (!mounted) return;
      widget.onChanged();
      AppToast.show(context, '업무 상태를 저장했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('업무 상태', style: AppTextStyles.title3),
          SizedBox(height: 6),
          Text(
            '조직도·사내톡·팀원 목록에서 다른 사람들에게 보여지는 상태입니다.',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          for (var row = 0; row < 3; row++) ...[
            if (row > 0) SizedBox(height: 10),
            Row(
              children: [
                for (var col = 0; col < 2; col++) ...[
                  if (col > 0) SizedBox(width: 10),
                  Expanded(
                    child: row * 2 + col < _statuses.length
                        ? _StatusChip(
                            emoji: _statuses[row * 2 + col].emoji,
                            label: _statuses[row * 2 + col].label,
                            selected: _selected == _statuses[row * 2 + col],
                            onTap: () => setState(
                              () => _selected = _statuses[row * 2 + col],
                            ),
                          )
                        : SizedBox(),
                  ),
                ],
              ],
            ),
          ],
          SizedBox(height: 20),
          _FieldLabel('상태 메시지 (선택)'),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _InputBox(controller: _message, hint: '예) 14시까지 외근'),
              ),
              SizedBox(width: 10),
              _SmallPrimaryButton(label: '저장', busy: _saving, onTap: _save),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '"근무중" · "오프라인" 은 자동 판정이라 여기서 선택할 수 없어요. '
            '"자동" 을 선택하면 오늘 출퇴근 여부에 따라 자동으로 표시됩니다.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  _StatusChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 15)),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 화면 테마
// ---------------------------------------------------------------------------

class _ThemeCard extends StatefulWidget {
  _ThemeCard();

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  static const _names = ['라이트', '다크', '시스템 설정'];

  int get _selected => switch (ThemeController.mode) {
    ThemeMode.light => 0,
    ThemeMode.dark => 1,
    ThemeMode.system => 2,
  };

  void _select(ThemeMode mode) => ThemeController.set(context, mode);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('화면 테마', style: AppTextStyles.title3),
          SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: '현재 적용: ',
              style: AppTextStyles.caption,
              children: [
                TextSpan(
                  text: _names[_selected],
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          _ThemeOption(
            icon: CupertinoIcons.sun_max,
            name: '라이트',
            desc: '밝은 화면',
            selected: _selected == 0,
            onTap: () => _select(ThemeMode.light),
            preview: _ThemePreview(dark: false),
          ),
          SizedBox(height: 12),
          _ThemeOption(
            icon: CupertinoIcons.moon,
            name: '다크',
            desc: '어두운 화면',
            selected: _selected == 1,
            onTap: () => _select(ThemeMode.dark),
            preview: _ThemePreview(dark: true),
          ),
          SizedBox(height: 12),
          _ThemeOption(
            icon: CupertinoIcons.desktopcomputer,
            name: '시스템 설정',
            desc: 'OS 설정을 따름',
            selected: _selected == 2,
            onTap: () => _select(ThemeMode.system),
            preview: Row(
              children: [
                Expanded(child: _ThemePreview(dark: false)),
                Expanded(child: _ThemePreview(dark: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  _ThemeOption({
    required this.icon,
    required this.name,
    required this.desc,
    required this.selected,
    required this.onTap,
    required this.preview,
  });

  final IconData icon;
  final String name;
  final String desc;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.gray100,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: preview,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.textPrimary),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(desc, style: AppTextStyles.caption),
                    ],
                  ),
                  Spacer(),
                  if (selected)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.checkmark,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  _ThemePreview({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? Color(0xFF0D1117) : AppColors.gray50;
    final surface = dark ? Color(0xFF1B222C) : Colors.white;
    final bar = dark ? Color(0xFF2A3441) : AppColors.gray200;

    return Container(
      color: bg,
      padding: EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: double.infinity,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: bar,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 6),
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: bar,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 비밀번호 변경 / 회원 탈퇴
// ---------------------------------------------------------------------------

class _PasswordCard extends StatefulWidget {
  _PasswordCard();

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final current = _current.text;
    final next = _next.text;
    if (current.isEmpty || next.isEmpty) {
      AppToast.show(context, '비밀번호를 모두 입력해주세요');
      return;
    }
    // 서버도 8자 미만이면 422 를 주지만, 안내가 여기서 나는 게 낫다
    if (next.length < 8) {
      AppToast.show(context, '새 비밀번호는 8자 이상이어야 해요');
      return;
    }
    if (next != _confirm.text) {
      AppToast.show(context, '새 비밀번호가 서로 달라요');
      return;
    }

    setState(() => _saving = true);
    try {
      await StaffApi.changePassword(
        currentPassword: current,
        newPassword: next,
      );

      // 서버가 토큰 버전을 올려서 **지금 쓰던 토큰도 같이 죽는다** —
      // access 만이 아니라 refresh 까지 401 이 된다 (직접 확인).
      // 그냥 두면 다음 요청에서 '세션이 만료됐어요' 로 튕긴다.
      // 새 비밀번호로 다시 들어가 이 기기만 이어 준다.
      final session = AuthSession.instance;
      await session.signIn(
        email: currentUser?.email ?? session.email ?? '',
        password: next,
        autoLogin: session.autoLogin,
      );

      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      AppToast.show(context, '비밀번호를 바꿨어요. 다른 기기는 다시 로그인해야 해요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('비밀번호 변경', style: AppTextStyles.title3),
          SizedBox(height: 20),
          _FieldLabel('현재 비밀번호'),
          SizedBox(height: 8),
          _InputBox(controller: _current, obscure: true),
          SizedBox(height: 20),
          _FieldLabel('새 비밀번호 (8자 이상)'),
          SizedBox(height: 8),
          _InputBox(controller: _next, obscure: true),
          SizedBox(height: 20),
          _FieldLabel('새 비밀번호 확인'),
          SizedBox(height: 8),
          _InputBox(
            controller: _confirm,
            obscure: true,
            helper: '바꾸면 이 기기만 남고 다른 기기는 로그아웃돼요.',
          ),
          SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: _SmallPrimaryButton(
              label: '비밀번호 변경',
              busy: _saving,
              onTap: _change,
            ),
          ),
        ],
      ),
    );
  }
}

/// 로그아웃 — 확인을 한 번 받고 로그인 화면으로 돌아간다
class _LogoutCard extends StatelessWidget {
  _LogoutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('로그아웃', style: AppTextStyles.title3),
          SizedBox(height: 8),
          Text(
            '이 기기에서 로그아웃해요. 자동 로그인을 켜 뒀더라도 '
            '다음에 들어올 때는 다시 로그인해야 해요.',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              onTap: () => confirmLogout(context),
              scale: 0.94,
              child: Container(
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '로그아웃',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawCard extends StatelessWidget {
  _WithdrawCard();

  /// 탈퇴 — 되돌릴 수 없어서 두 번 묻는다
  Future<void> _withdraw(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: '정말 탈퇴할까요?',
      message: '되돌릴 수 없어요. 계정이 비활성화되고 이름·연락처가 지워져요.',
      confirmLabel: '탈퇴하기',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await StaffApi.withdraw();
    } catch (error) {
      // 대표가 혼자면 서버가 막는다 (승인권이 비어 버린다)
      if (context.mounted) AppToast.show(context, messageOf(error));
      return;
    }
    if (!context.mounted) return;
    // 로그아웃과 같은 순서 — 얹혀 있는 화면부터 걷어내고 세션을 끊는다
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    await AuthSession.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '회원 탈퇴',
            style: AppTextStyles.title3.copyWith(color: AppColors.error),
          ),
          SizedBox(height: 8),
          Text(
            '탈퇴하면 이름·연락처 등 개인 식별 정보와 로그인 수단이 삭제되고 '
            '계정이 비활성화돼요. 회사가 법적으로 보관해야 하는 근태·급여 기록은 '
            '익명 처리되어 일정 기간 보존될 수 있어요.',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              onTap: () => _withdraw(context),
              scale: 0.94,
              child: Container(
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '회원 탈퇴하기',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 공용 소품
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.label.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  _InputBox({
    this.controller,
    this.value,
    this.hint,
    this.enabled = true,
    this.obscure = false,
    this.helper,
    this.keyboardType,
  });

  /// 고칠 수 있는 칸은 컨트롤러를 받는다.
  /// 예전에는 `initialValue` 만 넘겼는데 그러면 **적은 값을 꺼낼 수가 없다**
  final TextEditingController? controller;

  /// 읽기 전용 칸에 보여줄 값
  final String? value;

  final String? hint;
  final bool enabled;
  final bool obscure;
  final String? helper;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: enabled
              ? TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  style: AppTextStyles.body2,
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTextStyles.body2.copyWith(
                      color: AppColors.gray400,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                )
              : Text(
                  value ?? '',
                  style: AppTextStyles.body2.copyWith(color: AppColors.gray400),
                ),
        ),
        if (helper != null) ...[
          SizedBox(height: 8),
          Text(helper!, style: AppTextStyles.caption),
        ],
      ],
    );
  }
}

class _SmallPrimaryButton extends StatelessWidget {
  _SmallPrimaryButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;

  /// 서버에 보내는 중 — 연타로 두 번 저장되지 않게 막는다
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? () {} : onTap,
      scale: 0.94,
      child: Container(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: busy ? AppColors.gray300 : AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          widthFactor: 1,
          child: busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 서버는 아바타 색을 `#RRGGBB` 로 받는다
String _hexOf(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
