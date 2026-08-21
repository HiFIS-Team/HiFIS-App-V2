part of 'profile_screen.dart';

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
