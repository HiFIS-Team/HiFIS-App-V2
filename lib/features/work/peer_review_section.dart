import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/pressable.dart';

/// 동료 평가 탭 콘텐츠 (목업)
///
/// 사람마다 한 줄씩 나열되고, 줄을 누르면 평가 화면으로 이동한다.
/// 본인은 항목당 최대 5점, 동료는 항목당 최대 20점.
class PeerReviewSection extends StatelessWidget {
  PeerReviewSection({super.key});

  void _openForm(BuildContext context, _Person person) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => _PeerReviewFormScreen(person: person)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(child: Text('평가 작성', style: AppTextStyles.label)),
                Text('평가할 사람을 선택하세요', style: AppTextStyles.caption),
              ],
            ),
          ),
          SizedBox(height: 8),
          for (var i = 0; i < _persons.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider),
            _PersonRow(
              person: _persons[i],
              onTap: () => _openForm(context, _persons[i]),
            ),
          ],
        ],
      ),
    );
  }
}

const _categories = ['업무 역량', '협업 소통', '성과 기여도', '태도·규정 준수', '리더십'];

const _me = '김은후';

/// 평가 대상 목록 — 본인이 맨 앞. 아바타 색은 사내톡 멤버 목록과 동일.
const _persons = [
  _Person(_me, '본인 평가', AppColors.primary, isSelf: true),
  _Person('이앨리스', '디자인팀 · 리드', AppColors.success),
  _Person('오민준', '개발팀 · 대리', Color(0xFF00A8B5)),
  _Person('신유나', '디자인팀 · 대리', Color(0xFF7C5CFC)),
  _Person('권지호', '영업팀 · 사원', Color(0xFFE0447C)),
];

/// 평가 대상 한 명
class _Person {
  const _Person(this.name, this.caption, this.color, {this.isSelf = false});

  final String name;

  /// 줄에 보여줄 소속·직책 (본인은 '본인 평가')
  final String caption;
  final Color color;
  final bool isSelf;

  int get maxScore => isSelf ? 5 : 20;
}

/// 사람 한 줄 — 아바타·이름·소속과 끝의 이동 화살표
class _PersonRow extends StatelessWidget {
  _PersonRow({required this.person, required this.onTap});

  final _Person person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      pressedColor: AppColors.gray50,
      borderRadius: BorderRadius.circular(12),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: person.color,
              shape: BoxShape.circle,
            ),
            child: Text(
              person.name.characters.first,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      person.name,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (person.isSelf) ...[
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '나',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  person.caption,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: person.isSelf
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: AppColors.gray300,
          ),
        ],
      ),
    );
  }
}

/// 평가 작성 화면 — 사람 줄을 누르면 옆에서 슬라이드되어 열린다.
/// 5개 항목에 점수(본인 5점/동료 20점)와 사유를 적고 제출한다.
class _PeerReviewFormScreen extends StatefulWidget {
  _PeerReviewFormScreen({required this.person});

  final _Person person;

  @override
  State<_PeerReviewFormScreen> createState() => _PeerReviewFormScreenState();
}

class _PeerReviewFormScreenState extends State<_PeerReviewFormScreen> {
  final Map<String, int> _scores = {};

  late final Map<String, TextEditingController> _reasons = {
    for (final category in _categories) category: TextEditingController(),
  };

  int get _max => widget.person.maxScore;

  int get _total => _scores.values.fold(0, (sum, v) => sum + v);

  /// 모든 항목에 점수와 사유가 채워져야 제출이 열린다
  bool get _complete => _categories.every(
    (c) => (_scores[c] ?? 0) > 0 && _reasons[c]!.text.trim().isNotEmpty,
  );

  @override
  void initState() {
    super.initState();
    // 사유 입력에 따라 제출 버튼 상태가 바뀌도록 갱신한다
    for (final controller in _reasons.values) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in _reasons.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _adjust(String category, int delta) {
    final next = ((_scores[category] ?? 0) + delta).clamp(0, _max);
    setState(() => _scores[category] = next);
  }

  void _submit() {
    if (!_complete) {
      AppToast.show(context, '모든 항목의 점수와 사유를 입력해주세요');
      return;
    }
    FocusScope.of(context).unfocus();
    AppToast.show(
      context,
      widget.person.isSelf
          ? '내 평가를 제출했습니다'
          : '${widget.person.name}님 평가를 제출했습니다',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 고정 타이틀 영역만큼 비워둔다
                SizedBox(height: 56),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          person.caption,
                          style: AppTextStyles.caption,
                        ),
                      ),
                      Text(
                        '총 $_total / ${_max * _categories.length}점',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      // 하단 글래스 제출 버튼에 가리지 않도록 여유를 둔다
                      MediaQuery.paddingOf(context).bottom + 96,
                    ),
                    children: [
                      for (final category in _categories) ...[
                        _ScoreRow(
                          label: category,
                          score: _scores[category] ?? 0,
                          maxScore: _max,
                          onAdjust: (delta) => _adjust(category, delta),
                        ),
                        SizedBox(height: 8),
                        // 왜 이 점수인지 사유를 적는 칸 — 여러 줄 입력
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _reasons[category],
                            style: AppTextStyles.body2,
                            cursorColor: AppColors.primary,
                            keyboardType: TextInputType.multiline,
                            minLines: 3,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: '왜 이 점수인지 적어주세요',
                              hintStyle: AppTextStyles.body2.copyWith(
                                color: AppColors.gray400,
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 상단 중앙 고정 타이틀 (터치는 아래로 통과)
          IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text(
                    person.isSelf ? '내 평가' : '${person.name} 평가',
                    style: AppTextStyles.title3,
                  ),
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
          // 하단 고정: 네이티브 리퀴드 글래스 제출 버튼 (키보드와 함께 상승)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: CNButton(
                        // 테마 전환 시 설정 유실 버그 회피용 재생성 키
                        key: ValueKey('pr-submit-${AppColors.isDark}'),
                        label: '평가 제출',
                        // 전 항목이 채워지기 전에는 글래스, 채워지면 파란
                        // 프로미넌트 글래스. 비활성화하면 iOS가 글래스 재질을
                        // 빼버려서 항상 활성으로 두고, 미완성 시 동작은
                        // _submit에서 무시한다.
                        style: _complete
                            ? CNButtonStyle.prominentGlass
                            : CNButtonStyle.glass,
                        tint: AppColors.primary,
                        height: 56,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 항목 라벨 + −/+ 점수 스테퍼 줄
class _ScoreRow extends StatelessWidget {
  _ScoreRow({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.onAdjust,
  });

  final String label;
  final int score;
  final int maxScore;
  final ValueChanged<int> onAdjust;

  @override
  Widget build(BuildContext context) {
    final active = score > 0;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        _StepButton(
          icon: CupertinoIcons.minus,
          color: active ? AppColors.error : AppColors.gray300,
          onTap: () => onAdjust(-1),
        ),
        SizedBox(
          width: 58,
          child: Center(
            child: Text.rich(
              TextSpan(
                text: '$score',
                style: AppTextStyles.body2.copyWith(
                  color: active ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: ' / $maxScore',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.gray400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _StepButton(
          icon: CupertinoIcons.plus,
          color: score < maxScore ? AppColors.primary : AppColors.gray300,
          onTap: () => onAdjust(1),
        ),
      ],
    );
  }
}

/// 점수 스테퍼 버튼 — 누르는 동안 원이 줄어들며 버튼 색으로 물든다
class _StepButton extends StatefulWidget {
  _StepButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: SizedBox(
        width: 38,
        height: 40,
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? 0.82 : 1.0,
            duration: Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 110),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _pressed
                    ? widget.color.withValues(alpha: 0.18)
                    : AppColors.gray50,
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 13, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}
