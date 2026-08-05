part of 'peer_review_section.dart';

/// 평가 작성 화면 — 사람 줄을 누르면 옆에서 슬라이드되어 열린다.
/// 5개 항목에 별점과 사유를 적고 제출한다.
///
/// [submitted] 가 있으면 이미 낸 평가라 **읽기만 한다.**
/// 서버가 같은 사람·같은 달 재제출을 409 로 막는다.
class _PeerReviewFormScreen extends StatefulWidget {
  _PeerReviewFormScreen({
    required this.person,
    required this.isSelf,
    this.submitted,
  });

  final Employee person;
  final bool isSelf;

  /// 이미 낸 평가 — 없으면 새로 쓰는 중
  final PeerReview? submitted;

  @override
  State<_PeerReviewFormScreen> createState() => _PeerReviewFormScreenState();
}

class _PeerReviewFormScreenState extends State<_PeerReviewFormScreen> {
  /// 항목별 별 개수 (점수가 아니라 별 개수를 담는다)
  late final Map<PeerCategory, int> _stars = {
    for (final category in PeerCategory.values)
      category: widget.submitted?.stars[category] ?? 0,
  };

  late final Map<PeerCategory, TextEditingController> _reasons = {
    for (final category in PeerCategory.values)
      category: TextEditingController(
        text: widget.submitted?.reasons[category] ?? '',
      ),
  };

  /// 이미 낸 평가를 열어 본 것 — 고칠 수 없다
  bool get _readOnly => widget.submitted != null;

  bool _saving = false;

  int get _perStar => peerPointsPerStar(isSelf: widget.isSelf);

  int get _total => _stars.values.fold(0, (sum, v) => sum + v) * _perStar;

  int get _maxTotal => peerStarCount * _perStar * PeerCategory.values.length;

  /// 모든 항목에 별점과 사유가 채워져야 제출이 열린다
  bool get _complete => PeerCategory.values.every(
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

  void _setStars(PeerCategory category, int stars) {
    if (_readOnly || (_stars[category] ?? 0) == stars) return;
    // 드래그로 별을 훑을 때 한 칸씩 걸리는 느낌을 준다
    HapticFeedback.selectionClick();
    setState(() => _stars[category] = stars);
  }

  Future<void> _submit() async {
    if (!_complete) {
      AppToast.show(context, '모든 항목의 점수와 사유를 입력해주세요');
      return;
    }
    if (_saving) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await PeerReviewApi.create(
        revieweeId: widget.person.id,
        period: periodKey(DateTime.now()),
        stars: _stars,
        reasons: {
          for (final entry in _reasons.entries)
            entry.key: entry.value.text.trim(),
        },
      );
      if (!mounted) return;
      AppToast.show(
        context,
        widget.isSelf ? '내 평가를 제출했습니다' : '${widget.person.name}님 평가를 제출했습니다',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, messageOf(error));
    }
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
                          '${widget.isSelf ? '본인 평가' : person.rank.label}'
                          ' · 별 1개 $_perStar점',
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
                if (_readOnly)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                    color: AppColors.gray50,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.lock_fill,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '이미 제출한 평가예요. 고칠 수 없어요',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      for (final category in PeerCategory.values) ...[
                        _StarRow(
                          label: category.label,
                          stars: _stars[category] ?? 0,
                          pointsPerStar: _perStar,
                          readOnly: _readOnly,
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
                            readOnly: _readOnly,
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
                    widget.isSelf ? '내 평가' : '${person.name} 평가',
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
          // 이미 낸 평가는 낼 것이 없으므로 버튼 자체를 두지 않는다
          if (!_readOnly)
            Align(
              alignment: Alignment.bottomCenter,
              child: BottomActionBar(
                children: [
                  Expanded(
                    child: BottomActionButton(
                      id: 'pr-submit',
                      label: _saving ? '제출 중...' : '평가 제출',
                      // 전 항목이 채워져야 채워진 상태가 되고,
                      // 미완성 시 동작은 _submit에서 무시한다
                      filled: _complete && !_saving,
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
    this.readOnly = false,
  });

  final String label;
  final int stars;
  final int pointsPerStar;
  final ValueChanged<int> onChanged;

  /// 이미 낸 평가를 보는 중이면 별을 못 건드린다
  final bool readOnly;

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
                    text: ' / ${peerStarCount * pointsPerStar}점',
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
        IgnorePointer(
          ignoring: readOnly,
          child: _StarPicker(stars: stars, onChanged: onChanged),
        ),
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

  int _starsAt(double dx) =>
      (dx / _slot).floor().clamp(0, peerStarCount - 1) + 1;

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
        width: _slot * peerStarCount,
        height: _height,
        child: Row(
          children: [
            for (var i = 0; i < peerStarCount; i++)
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
