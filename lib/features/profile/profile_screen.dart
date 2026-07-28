import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/top_frost.dart';

/// 내 프로필 화면 (목업)
///
/// 데이터는 하드코딩된 샘플이며, 계정 기능 연동 시 실제 데이터로 교체한다.
/// 저장/업로드/탈퇴 등 버튼 동작은 아직 비어 있다.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scrollController = ScrollController();

  /// 0(펼침) ~ 1(접힘). 스크롤에 따른 상단 블러 강도.
  double _collapse = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final t = ((_scrollController.offset - 30) / 30).clamp(0.0, 1.0);
    if (t != _collapse) setState(() => _collapse = t);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 68, 20, 40),
              children: const [
                Text('계정', style: AppTextStyles.caption),
                SizedBox(height: 4),
                Text('내 프로필', style: AppTextStyles.title1),
                SizedBox(height: 20),
                _ProfileSummaryCard(),
                SizedBox(height: 16),
                _BasicInfoCard(),
                SizedBox(height: 16),
                _WorkStatusCard(),
                SizedBox(height: 16),
                _ThemeCard(),
                SizedBox(height: 16),
                _PasswordCard(),
                SizedBox(height: 16),
                _WithdrawCard(),
              ],
            ),
          ),
          TopFrost(collapse: _collapse, color: AppColors.background),
          // 상단 중앙 고정 타이틀 (터치는 아래 리스트로 통과)
          const IgnorePointer(
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
              padding: const EdgeInsets.only(top: 8, left: 16),
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
  const _ProfileSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Avatar(size: 56),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('김은후', style: AppTextStyles.title2),
                  const SizedBox(height: 2),
                  Text(
                    'eunhoo@hifis.app',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(),
          ),
          const Row(
            children: [
              Expanded(
                child: _SummaryField(label: '사번', value: 'FS-0903'),
              ),
              Expanded(
                child: _SummaryField(label: '직급', value: '트레이너'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _SummaryField(label: '팀', value: 'PT팀'),
              ),
              Expanded(
                child: _SummaryField(label: '권한', value: 'MEMBER'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryField extends StatelessWidget {
  const _SummaryField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size, this.color = AppColors.primary});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        '김',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 기본 정보
// ---------------------------------------------------------------------------

class _BasicInfoCard extends StatefulWidget {
  const _BasicInfoCard();

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

  int _selectedColor = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('기본 정보', style: AppTextStyles.title3),
          const SizedBox(height: 20),
          const _FieldLabel('이름'),
          const SizedBox(height: 8),
          const _InputBox(initial: '김은후'),
          const SizedBox(height: 20),
          const _FieldLabel('프로필 이미지'),
          const SizedBox(height: 10),
          Row(
            children: [
              _Avatar(size: 56, color: _avatarColors[_selectedColor]),
              const SizedBox(width: 14),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  side: const BorderSide(color: AppColors.gray200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '이미지 업로드',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '이미지가 없을 땐 아래 아바타 색과 이름 첫 글자로 표시됩니다. (10MB 이하)',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 20),
          const _FieldLabel('아바타 색'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _avatarColors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _selectedColor = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _avatarColors[i],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: i == _selectedColor
                        ? const Icon(
                            CupertinoIcons.checkmark,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const _FieldLabel('이메일'),
          const SizedBox(height: 8),
          const _InputBox(
            initial: 'eunhoo@hifis.app',
            enabled: false,
            helper: '이메일은 관리자만 변경할 수 있습니다.',
          ),
          const SizedBox(height: 20),
          const _FieldLabel('사번'),
          const SizedBox(height: 8),
          const _InputBox(
            initial: 'FS-0903',
            enabled: false,
            helper: '가입 시 자동으로 부여됩니다.',
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerRight,
            child: _SmallPrimaryButton(label: '저장'),
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
  const _WorkStatusCard();

  @override
  State<_WorkStatusCard> createState() => _WorkStatusCardState();
}

class _WorkStatusCardState extends State<_WorkStatusCard> {
  static const _statuses = [
    (emoji: '🔄', label: '자동 (출근 기준)'),
    (emoji: '💼', label: '회의중'),
    (emoji: '🍽️', label: '식사'),
    (emoji: '🚶', label: '외출'),
    (emoji: '💤', label: '자리비움'),
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('업무 상태', style: AppTextStyles.title3),
          const SizedBox(height: 6),
          const Text(
            '조직도·사내톡·팀원 목록에서 다른 사람들에게 보여지는 상태입니다.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          for (var row = 0; row < 3; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            Row(
              children: [
                for (var col = 0; col < 2; col++) ...[
                  if (col > 0) const SizedBox(width: 10),
                  Expanded(
                    child: row * 2 + col < _statuses.length
                        ? _StatusChip(
                            emoji: _statuses[row * 2 + col].emoji,
                            label: _statuses[row * 2 + col].label,
                            selected: _selected == row * 2 + col,
                            onTap: () =>
                                setState(() => _selected = row * 2 + col),
                          )
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 20),
          const _FieldLabel('상태 메시지 (선택)'),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(child: _InputBox(hint: '예) 14시까지 외근')),
              SizedBox(width: 10),
              _SmallPrimaryButton(label: '저장'),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
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
  const _StatusChip({
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
    return GestureDetector(
      onTap: onTap,
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
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
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
  const _ThemeCard();

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  // TODO: 다크 모드 테마 구현 시 실제 테마 전환 연결
  int _selected = 0;

  static const _names = ['라이트', '다크', '시스템 설정'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('화면 테마', style: AppTextStyles.title3),
          const SizedBox(height: 4),
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
          const SizedBox(height: 16),
          _ThemeOption(
            icon: CupertinoIcons.sun_max,
            name: '라이트',
            desc: '밝은 화면',
            selected: _selected == 0,
            onTap: () => setState(() => _selected = 0),
            preview: const _ThemePreview(dark: false),
          ),
          const SizedBox(height: 12),
          _ThemeOption(
            icon: CupertinoIcons.moon,
            name: '다크',
            desc: '어두운 화면',
            selected: _selected == 1,
            onTap: () => setState(() => _selected = 1),
            preview: const _ThemePreview(dark: true),
          ),
          const SizedBox(height: 12),
          _ThemeOption(
            icon: CupertinoIcons.desktopcomputer,
            name: '시스템 설정',
            desc: 'OS 설정을 따름',
            selected: _selected == 2,
            onTap: () => setState(() => _selected = 2),
            preview: const Row(
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
  const _ThemeOption({
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
    return GestureDetector(
      onTap: onTap,
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: preview,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.textPrimary),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(desc, style: AppTextStyles.caption),
                    ],
                  ),
                  const Spacer(),
                  if (selected)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
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
  const _ThemePreview({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF0D1117) : AppColors.gray50;
    final surface = dark ? const Color(0xFF1B222C) : Colors.white;
    final bar = dark ? const Color(0xFF2A3441) : AppColors.gray200;

    return Container(
      color: bg,
      padding: const EdgeInsets.all(14),
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
          const SizedBox(width: 10),
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
                const SizedBox(height: 6),
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
                const SizedBox(height: 10),
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

class _PasswordCard extends StatelessWidget {
  const _PasswordCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.card(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('비밀번호 변경', style: AppTextStyles.title3),
          SizedBox(height: 20),
          _FieldLabel('현재 비밀번호'),
          SizedBox(height: 8),
          _InputBox(obscure: true),
          SizedBox(height: 20),
          _FieldLabel('새 비밀번호 (8자 이상)'),
          SizedBox(height: 8),
          _InputBox(obscure: true),
          SizedBox(height: 20),
          _FieldLabel('새 비밀번호 확인'),
          SizedBox(height: 8),
          _InputBox(obscure: true),
          SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: _SmallPrimaryButton(label: '비밀번호 변경'),
          ),
        ],
      ),
    );
  }
}

class _WithdrawCard extends StatelessWidget {
  const _WithdrawCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
          const SizedBox(height: 8),
          const Text(
            '탈퇴하면 이름·연락처 등 개인 식별 정보와 로그인 수단이 삭제되고 '
            '계정이 비활성화돼요. 회사가 법적으로 보관해야 하는 근태·급여 기록은 '
            '익명 처리되어 일정 기간 보존될 수 있어요.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '회원 탈퇴하기',
              style: AppTextStyles.label.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
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
  const _FieldLabel(this.text);

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
  const _InputBox({
    this.initial,
    this.hint,
    this.enabled = true,
    this.obscure = false,
    this.helper,
  });

  final String? initial;
  final String? hint;
  final bool enabled;
  final bool obscure;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: enabled
              ? TextFormField(
                  initialValue: initial,
                  obscureText: obscure,
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
                  initial ?? '',
                  style: AppTextStyles.body2.copyWith(color: AppColors.gray400),
                ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 8),
          Text(helper!, style: AppTextStyles.caption),
        ],
      ],
    );
  }
}

class _SmallPrimaryButton extends StatelessWidget {
  const _SmallPrimaryButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    );
  }
}
