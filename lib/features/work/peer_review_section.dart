import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/glass_bottom_button.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_bar.dart';

/// 동료 평가 탭 콘텐츠 (목업)
///
/// 사람마다 한 줄씩 나열되고, 줄을 누르면 평가 화면으로 이동한다.
/// 점수는 항목마다 별 5개로 매기고, 별 하나의 가치가 대상에 따라 다르다
/// (본인 1점 → 항목 최대 5점 / 동료 5점 → 항목 최대 25점).
class PeerReviewSection extends StatefulWidget {
  PeerReviewSection({super.key});

  @override
  State<PeerReviewSection> createState() => _PeerReviewSectionState();
}

class _PeerReviewSectionState extends State<PeerReviewSection> {
  /// 평가 작성 — 폰은 밀려 들어오고 PC는 모달로 뜬다
  Future<void> _openForm(_Person person) async {
    await showFullPage<bool>(
      context,
      (_) => _PeerReviewFormScreen(person: person),
    );
    // 제출하고 돌아왔을 수 있으니 진행 상황을 새로 그린다
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 아직 안 한 사람이 위로 온다 — 무엇이 남았는지가 이 화면의 용건이다
    final pending = _persons
        .where((p) => !_submitted.contains(p.name))
        .toList();
    final done = _persons.where((p) => _submitted.contains(p.name)).toList();
    final ordered = [...pending, ...done];

    return Column(
      children: [
        _ReviewProgress(done: done.length, total: _persons.length),
        SizedBox(height: 16),
        Container(
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
                    Text(
                      pending.isEmpty ? '모두 마쳤어요' : '남은 ${pending.length}명',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pending.isEmpty
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              for (var i = 0; i < ordered.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppColors.divider),
                _PersonRow(
                  person: ordered[i],
                  done: _submitted.contains(ordered[i].name),
                  onTap: () => _openForm(ordered[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 이번 달 평가 진행 — 몇 명 중 몇 명을 마쳤는지
class _ReviewProgress extends StatelessWidget {
  _ReviewProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final left = total - done;
    final finished = left == 0;
    final color = finished ? AppColors.success : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  '${DateTime.now().month}월 동료 평가',
                  style: AppTextStyles.label,
                ),
              ),
              Text('$done', style: AppTextStyles.title2.copyWith(color: color)),
              Text(
                ' / $total명',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          ProgressBar(ratio: total == 0 ? 0 : done / total, color: color),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(
                finished
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.pencil_circle_fill,
                size: 14,
                color: color,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  finished ? '이번 달 평가를 모두 마쳤어요' : '$left명 남았어요',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _categories = ['업무 역량', '협업 소통', '성과 기여도', '태도·규정 준수', '리더십'];

/// 항목마다 매길 수 있는 별 개수 (대상과 무관하게 5개)
const _starCount = 5;

const _me = '김피스';

/// 이번 달 평가를 제출한 사람 (목업)
///
/// 탭을 오가도 남아 있어야 해서 모듈 전역으로 둔다.
/// 실제 연동 때는 서버에서 내려받은 제출 이력으로 바꾼다.
final _submitted = <String>{};

/// 평가 대상 목록 — 본인이 맨 앞. 아바타 색은 사내톡 멤버 목록과 동일.
const _persons = [
  _Person(_me, '본인 평가', AppColors.primary, isSelf: true),
  _Person('이준승', '대표', Color(0xFF7C5CFC)),
  _Person('이준경', '개발', Color(0xFF00A8B5)),
  _Person('민중기', '점장', AppColors.success),
  _Person('박준현', '트레이너', AppColors.warning),
  _Person('유찬빈', '트레이너', Color(0xFF5C7CFA)),
  _Person('전상현', 'FC', Color(0xFFE0447C)),
];

/// 평가 대상 한 명
class _Person {
  const _Person(this.name, this.caption, this.color, {this.isSelf = false});

  final String name;

  /// 줄에 보여줄 소속·직책 (본인은 '본인 평가')
  final String caption;
  final Color color;
  final bool isSelf;

  /// 별 하나의 점수 — 본인 평가보다 동료 평가의 비중이 크다
  int get pointsPerStar => isSelf ? 1 : 5;

  /// 항목 하나의 만점
  int get maxScore => pointsPerStar * _starCount;
}

/// 사람 한 줄 — 아바타·이름·소속과 끝의 이동 화살표
///
/// 이미 평가한 사람은 아바타가 한 톤 흐려지고 끝에 체크가 붙는다.
/// (다시 눌러 고쳐 쓸 수는 있다)
class _PersonRow extends StatelessWidget {
  _PersonRow({required this.person, required this.onTap, this.done = false});

  final _Person person;
  final VoidCallback onTap;
  final bool done;

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
              color: done ? person.color.withValues(alpha: 0.35) : person.color,
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
                  done ? '평가 완료' : person.caption,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                    color: done
                        ? AppColors.success
                        : person.isSelf
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            done
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.chevron_right,
            size: 16,
            color: done ? AppColors.success : AppColors.gray300,
          ),
        ],
      ),
    );
  }
}

/// 평가 작성 화면 — 사람 줄을 누르면 옆에서 슬라이드되어 열린다.
/// 5개 항목에 별점과 사유를 적고 제출한다.
class _PeerReviewFormScreen extends StatefulWidget {
  _PeerReviewFormScreen({required this.person});

  final _Person person;

  @override
  State<_PeerReviewFormScreen> createState() => _PeerReviewFormScreenState();
}

class _PeerReviewFormScreenState extends State<_PeerReviewFormScreen> {
  /// 항목별 별 개수 (점수가 아니라 별 개수를 담는다)
  final Map<String, int> _stars = {};

  late final Map<String, TextEditingController> _reasons = {
    for (final category in _categories) category: TextEditingController(),
  };

  int get _perStar => widget.person.pointsPerStar;

  int get _total => _stars.values.fold(0, (sum, v) => sum + v) * _perStar;

  int get _maxTotal => widget.person.maxScore * _categories.length;

  /// 모든 항목에 별점과 사유가 채워져야 제출이 열린다
  bool get _complete => _categories.every(
    (c) => (_stars[c] ?? 0) > 0 && _reasons[c]!.text.trim().isNotEmpty,
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

  void _setStars(String category, int stars) {
    if ((_stars[category] ?? 0) == stars) return;
    // 드래그로 별을 훑을 때 한 칸씩 걸리는 느낌을 준다
    HapticFeedback.selectionClick();
    setState(() => _stars[category] = stars);
  }

  void _submit() {
    if (!_complete) {
      AppToast.show(context, '모든 항목의 점수와 사유를 입력해주세요');
      return;
    }
    FocusScope.of(context).unfocus();
    _submitted.add(widget.person.name);
    AppToast.show(
      context,
      widget.person.isSelf
          ? '내 평가를 제출했습니다'
          : '${widget.person.name}님 평가를 제출했습니다',
    );
    Navigator.pop(context, true);
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
                          '${person.caption} · 별 1개 $_perStar점',
                          style: AppTextStyles.caption,
                        ),
                      ),
                      Text(
                        '총 $_total / $_maxTotal점',
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
                        _StarRow(
                          label: category,
                          stars: _stars[category] ?? 0,
                          pointsPerStar: _perStar,
                          onChanged: (v) => _setStars(category, v),
                        ),
                        SizedBox(height: 12),
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
          // 하단 고정: 제출 버튼 (키보드와 함께 상승)
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomActionBar(
              children: [
                Expanded(
                  child: BottomActionButton(
                    id: 'pr-submit',
                    label: '평가 제출',
                    // 전 항목이 채워져야 채워진 상태가 되고,
                    // 미완성 시 동작은 _submit에서 무시한다
                    filled: _complete,
                    onPressed: _submit,
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

/// 항목 한 칸 — 라벨·환산 점수 줄 + 별점 줄
class _StarRow extends StatelessWidget {
  _StarRow({
    required this.label,
    required this.stars,
    required this.pointsPerStar,
    required this.onChanged,
  });

  final String label;
  final int stars;
  final int pointsPerStar;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = stars > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                style: AppTextStyles.body2.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text.rich(
              TextSpan(
                text: '${stars * pointsPerStar}',
                style: AppTextStyles.body2.copyWith(
                  color: active ? AppColors.primary : AppColors.gray400,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: ' / ${_starCount * pointsPerStar}점',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.gray400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        _StarPicker(stars: stars, onChanged: onChanged),
      ],
    );
  }
}

/// 별 5개 선택기 — 누르거나 가로로 쭉 그어서 한 번에 매긴다.
/// 이미 선택된 별을 다시 누르면 0으로 지워진다.
class _StarPicker extends StatelessWidget {
  _StarPicker({required this.stars, required this.onChanged});

  final int stars;
  final ValueChanged<int> onChanged;

  /// 별 하나가 차지하는 가로 칸 (아이콘 + 여백) — 이 값으로 좌표를 나눠 인덱스를 구한다
  static const _slot = 40.0;
  static const _icon = 32.0;
  static const _height = 40.0;

  int _starsAt(double dx) => (dx / _slot).floor().clamp(0, _starCount - 1) + 1;

  void _tap(double dx) {
    final next = _starsAt(dx);
    // 같은 별을 다시 누르면 해제 (잘못 준 점수를 지울 방법)
    onChanged(next == stars ? 0 : next);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _tap(d.localPosition.dx),
      onHorizontalDragStart: (d) => onChanged(_starsAt(d.localPosition.dx)),
      onHorizontalDragUpdate: (d) => onChanged(_starsAt(d.localPosition.dx)),
      child: SizedBox(
        width: _slot * _starCount,
        height: _height,
        child: Row(
          children: [
            for (var i = 0; i < _starCount; i++)
              SizedBox(
                width: _slot,
                child: Icon(
                  Icons.star_rounded,
                  size: _icon,
                  color: i < stars ? AppColors.primary : AppColors.gray200,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
