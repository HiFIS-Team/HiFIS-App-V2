part of 'profile_screen.dart';

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

  /// 검증에 걸린 칸으로 커서를 옮기려면 필요하다 — 어느 칸인지 알려 주는 게
  /// 토스트 문구만으로는 부족하다 (다른 폼들과 같은 방식)
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppToast.show(context, '이름을 입력해주세요');
      _nameFocus.requestFocus();
      return;
    }
    // 비워 두는 건 괜찮다 — 적었으면 제대로 적어야 한다
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (phone.isNotEmpty && (phone.length != 11 || !phone.startsWith('01'))) {
      AppToast.show(context, '휴대폰 번호 11자리를 입력해주세요');
      _phoneFocus.requestFocus();
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

  /// 프로필 사진 고르기 — 서버가 png·jpg·jpeg·gif·webp 만 받는다
  ///
  /// **폰은 사진첩을 연다.** 확장자로 거르는 고르개(`FileType.custom`)는
  /// iOS 에서 '파일' 앱을 여는데 거기서는 사진첩을 못 뒤진다 — 프로필 사진을
  /// 고를 길이 아예 없었다 (사내톡 첨부와 같은 문제였다).
  ///
  /// 폰에서는 확장자를 못 거는 대신 `compressionQuality` 로 막는다. 아이폰
  /// 사진은 HEIC 라 그대로 보내면 서버가 400 `INVALID_IMAGE` 를 주는데,
  /// 0 보다 크면 사진첩이 호환 포맷(JPEG)으로 바꿔서 준다.
  Future<void> _pickImage() async {
    final phone = !isDesktop;
    final picked = await FilePicker.pickFiles(
      dialogTitle: '프로필 사진 선택',
      type: phone ? FileType.image : FileType.custom,
      allowedExtensions: phone
          ? null
          : const ['png', 'jpg', 'jpeg', 'gif', 'webp'],
      compressionQuality: phone ? 100 : 0,
    );
    final file = picked?.files.singleOrNull;
    final path = file?.path;
    if (file == null || path == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      // 올리기 전에 줄인다 — 사진첩 원본은 3~5MB 라 느리고, 서버는 5MB 를
      // 넘기면 `IMAGE_TOO_LARGE` 로 튕긴다
      final (small, smallName) = await shrinkPhoto(path, file.name);
      applyCurrentUser(await StaffApi.uploadAvatar(small, filename: smallName));
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
          _InputBox(controller: _name, focusNode: _nameFocus),
          SizedBox(height: 20),
          _FieldLabel('전화번호'),
          SizedBox(height: 8),
          _InputBox(
            controller: _phone,
            focusNode: _phoneFocus,
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
