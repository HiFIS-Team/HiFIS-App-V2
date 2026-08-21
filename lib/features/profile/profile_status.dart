part of 'profile_screen.dart';

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
