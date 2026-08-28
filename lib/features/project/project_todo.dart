part of 'project_screen.dart';

/// 할 일 체크리스트 — 체크 비율이 그대로 진행률이 된다.
/// 할 일은 프로젝트를 만들 때 받으므로 여기서는 체크·담당자 변경·삭제만 한다.
class _TodoCard extends StatelessWidget {
  _TodoCard({
    required this.project,
    required this.onToggle,
    required this.onRemove,
    required this.onAssign,
  });

  final _Project project;
  final ValueChanged<_Todo> onToggle;
  final ValueChanged<_Todo> onRemove;
  final ValueChanged<_Todo> onAssign;

  @override
  Widget build(BuildContext context) {
    final todos = project.todos;
    final locked = _isLocked(project);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('할 일', style: AppTextStyles.label),
          SizedBox(height: 6),
          if (todos.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                '등록된 할 일이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (final todo in todos)
              _TodoRow(
                todo: todo,
                // 완료된 프로젝트는 눌러도 서버가 403 을 준다 — 아예 안 먹게 한다.
                // 체크만 한 겹 더 잠근다 — **그 할 일의 담당자와 PM 만** 누른다
                // (2026-08-20, 서버 `NOT_TODO_ASSIGNEE`)
                onToggle: locked || !_canCheckTodo(project, todo)
                    ? null
                    : () => onToggle(todo),
                onRemove: locked ? null : () => onRemove(todo),
                onAssign: locked ? null : () => onAssign(todo),
              ),
        ],
      ),
    );
  }
}

/// 할 일 한 줄 — 체크·내용·담당자, 커서를 올리면 삭제가 나온다
class _TodoRow extends StatefulWidget {
  _TodoRow({
    required this.todo,
    required this.onToggle,
    required this.onRemove,
    required this.onAssign,
  });

  final _Todo todo;

  /// 완료된 프로젝트에서는 셋 다 null 이다 — 자리는 그대로 두고 안 눌리게만 한다
  final VoidCallback? onToggle;
  final VoidCallback? onRemove;
  final VoidCallback? onAssign;

  @override
  State<_TodoRow> createState() => _TodoRowState();
}

class _TodoRowState extends State<_TodoRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final todo = widget.todo;
    final toggle = widget.onToggle;
    final remove = widget.onRemove;
    // 폰은 커서가 없으니 삭제 버튼을 항상 띄워둔다
    final showRemove = remove != null && (_hover || !isDesktop);

    final box = Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: todo.done ? AppColors.primary : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: todo.done ? AppColors.primary : AppColors.gray300,
          width: 1.5,
        ),
      ),
      child: todo.done
          ? Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            if (toggle == null) box else Pressable(onTap: toggle, child: box),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                todo.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  color: todo.done
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  decoration: todo.done ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.gray400,
                ),
              ),
            ),
            SizedBox(width: 8),
            _AssigneeChip(name: todo.assignee, onTap: widget.onAssign),
            SizedBox(width: 4),
            SizedBox(
              width: 28,
              child: showRemove
                  ? Pressable(
                      onTap: remove,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.gray400,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 담당자 알약 — 누르면 참여자 중에서 고른다
class _AssigneeChip extends StatelessWidget {
  _AssigneeChip({required this.name, required this.onTap, this.filled = false});

  final String? name;

  /// null 이면 못 고친다 (완료된 프로젝트) — 모양은 그대로 두고 안 눌리게만 한다
  final VoidCallback? onTap;

  /// 회색 면을 깔지 — **혼자 서는 자리에서만 켠다.**
  ///
  /// 할 일 목록에서는 줄 끝에 붙는 것이라 면이 없어야 조용하다. 반면
  /// 할 일 **추가 줄**에서는 왼쪽에 혼자 서는데, 면이 없으면 눌러야 하는
  /// 것인지가 안 보인다 — 오른쪽의 파란 `추가` 와 나란히 놓이면 더 그렇다.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final assigned = name != null;
    final padding = filled
        ? EdgeInsets.fromLTRB(assigned ? 4 : 12, 4, 12, 4)
        : EdgeInsets.fromLTRB(assigned ? 3 : 8, 3, 8, 3);
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (assigned) ...[Avatar(name: name!, size: 20), SizedBox(width: 5)],
        Text(
          assigned ? name! : '담당자',
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            color: assigned ? AppColors.textSecondary : AppColors.gray400,
            fontWeight: assigned ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );

    final tap = onTap;
    if (!filled) {
      if (tap == null) return Padding(padding: padding, child: chip);
      return Pressable(onTap: tap, padding: padding, child: chip);
    }

    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(100),
      ),
      child: chip,
    );
    return tap == null ? box : Pressable(onTap: tap, child: box);
  }
}

/// 할 일 입력 줄 (생성 폼 전용) — 적고 엔터를 치면 바로 아래 목록에 쌓인다
class _TodoComposer extends StatefulWidget {
  _TodoComposer({required this.members, required this.onAdd});

  final List<String> members;
  final void Function(String text, String? assignee) onAdd;

  @override
  State<_TodoComposer> createState() => _TodoComposerState();
}

class _TodoComposerState extends State<_TodoComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// 몇 개를 한 번에 붙일지 — **비워 두면 1개다**
  ///
  /// 같은 일을 여러 번 해야 하는 자리(전단지 배포 3회처럼)를 한 줄로 적으면
  /// 체크를 한 번밖에 못 한다. 개수만큼 줄을 만들어 하나씩 체크하게 한다.
  final _count = TextEditingController();

  String? _assignee;

  /// 적힌 개수 — 비었거나 0 이면 1, 두 자리까지만 받는다(`maxLength`)
  int get _times {
    final n = int.tryParse(_count.text.trim()) ?? 1;
    return n < 1 ? 1 : n;
  }

  @override
  void dispose() {
    _controller.dispose();
    _count.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // 담당자를 안 고르면 여기서 막는다 (2026-08-19 대표 결정) — 다 적고 나서
    // '만들기' 에서 걸리면 어느 줄이 비었는지 되짚어야 한다
    if (_assignee == null) {
      AppToast.show(context, '할 일을 맡을 사람을 골라주세요');
      return;
    }
    final times = _times;
    for (var i = 1; i <= times; i++) {
      // 여러 개일 때만 번호를 붙인다 — 1개짜리에 `청소 1` 이 뜨면 어색하다
      widget.onAdd(times == 1 ? text : '$text $i', _assignee);
    }
    _controller.clear();
    // **개수는 되돌린다.** 담당자와 달리 그대로 두면 다음에 한 줄만 적었는데
    // 세 줄이 붙는다 — 눌러 보기 전에는 안 보이는 자리라 놀란다.
    _count.clear();
    // 연달아 적을 수 있게 담당자와 포커스는 유지한다
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // **두 줄로 나눈다** (2026-08-28 대표 지적).
    //
    // 예전에는 한 줄에 넷이 들어갔다 — `[할 일] [개수] [담당자] [+]`.
    // 폰 폭 375 에서 좌우 여백을 빼면 335 인데, 뒤의 셋이 185 를 가져가서
    // **정작 적는 칸에 150 밖에 안 남았다.** 게다가 개수 칸은 라벨도 힌트도
    // `1` 뿐이라 그게 무엇인지 알 방법이 없었다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1줄 — 적는 칸이 폭을 다 쓴다
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            style: AppTextStyles.body2,
            cursorColor: AppColors.primary,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: '할 일을 적어주세요',
              hintStyle: AppTextStyles.body2.copyWith(color: AppColors.gray400),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ),
        SizedBox(height: 8),
        // 2줄 — 누구에게 · 몇 개 · 추가
        Row(
          children: [
            _AssigneeChip(
              name: _assignee,
              filled: true,
              onTap: () async {
                final picked = await _pickMember(
                  context,
                  names: widget.members,
                  current: _assignee,
                );
                if (picked == null) return;
                setState(() => _assignee = picked.isEmpty ? null : picked);
                _focus.requestFocus();
              },
            ),
            Spacer(),
            // 같은 할 일을 여러 개 만든다 (`청소 1` `청소 2` …).
            // **`개` 를 붙여야 무엇을 세는 칸인지 보인다** — 예전에는 회색 `1`
            // 하나만 떠 있어서 눌러 보기 전에는 뜻을 알 수 없었다
            Container(
              width: 40,
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _count,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                // 두 자리까지 — 같은 할 일을 100개 붙일 일은 없다
                maxLength: 2,
                style: AppTextStyles.body2,
                cursorColor: AppColors.primary,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: '1',
                  hintStyle: AppTextStyles.body2.copyWith(
                    color: AppColors.gray400,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  counterText: '', // 글자 수 표시가 줄 아래로 삐져나온다
                ),
              ),
            ),
            SizedBox(width: 5),
            Text(
              '개',
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            SizedBox(width: 10),
            // **글자를 넣는다.** `+` 만 있으면 무엇이 더해지는지가 안 보인다
            Pressable(
              onTap: _submit,
              child: Container(
                height: 36,
                padding: EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      '추가',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
