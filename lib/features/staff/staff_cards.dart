part of 'staff_screen.dart';

// ---------------------------------------------------------------------------
// 명단 카드 · 줄
// ---------------------------------------------------------------------------

/// 아바타 우하단에 상태 점을 붙인 아바타
class _StatusAvatar extends StatelessWidget {
  _StatusAvatar({required this.member, this.size = 44});

  final _Member member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.29;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Avatar(name: member.name, size: size, imageUrl: member.avatarUrl),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: member.status.color,
                shape: BoxShape.circle,
                // 아바타 색과 붙어 보이지 않게 배경색으로 테를 두른다
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatefulWidget {
  _MemberCard({
    required this.showBranch,
    required this.member,
    required this.onTap,
    required this.onChat,
    required this.onCopy,
  });

  /// 전체 지점을 보고 있을 때만 어느 지점 사람인지 같이 보여준다
  final bool showBranch;

  final _Member member;
  final VoidCallback onTap;
  final VoidCallback onChat;
  final VoidCallback onCopy;

  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> {
  bool _hovered = false;

  /// 상태마다 할 수 있는 일이 다르다 — 퇴사자는 연락처만, 나머지는 대화.
  ///
  /// **알바도 재직자와 같다.** 일하는 사람이라 대화를 걸 수 있어야 한다.
  /// 퇴사 처리는 인사 정보 변경 화면에 있다 (staff_manage.dart).
  List<Widget> _actions() {
    final member = widget.member;
    final copy = _IconAction(
      icon: CupertinoIcons.doc_on_doc,
      onTap: widget.onCopy,
    );

    if (member.employment == _Employment.left) {
      return [
        Expanded(
          child: _SmallButton(label: '연락처 보기', onTap: widget.onTap),
        ),
        SizedBox(width: 8),
        copy,
      ];
    }

    return [
      Expanded(child: _ChatButton(onTap: widget.onChat)),
      SizedBox(width: 8),
      copy,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Pressable(
        onTap: widget.onTap,
        scale: 0.985,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 140),
          padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            // 커서를 올린 카드만 테두리에 색을 준다
            border: Border.all(
              color: _hovered ? AppColors.primary : AppColors.gray100,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusAvatar(member: member),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.title3,
                              ),
                            ),
                            if (member.isMe) ...[SizedBox(width: 6), _MeTag()],
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          widget.showBranch
                              ? '${member.branchLabel} · ${member.role}'
                              : member.role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6),
                  // 직군은 머리말에 이미 있으니 여기는 권한을 보여준다
                  _PermissionTag(permission: member.permission),
                ],
              ),
              SizedBox(height: 14),
              Text(
                member.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
              SizedBox(height: 8),
              _StatusLine(member: member),
              SizedBox(height: 14),
              Row(children: _actions()),
            ],
          ),
        ),
      ),
    );
  }
}

/// 목록 보기 한 줄 — 카드와 같은 정보를 가로로 편다
class _MemberRow extends StatefulWidget {
  _MemberRow({
    required this.showBranch,
    required this.member,
    required this.onTap,
    required this.onChat,
    required this.onCopy,
  });

  /// 전체 지점을 보고 있을 때만 어느 지점 사람인지 같이 보여준다
  final bool showBranch;

  final _Member member;
  final VoidCallback onTap;
  final VoidCallback onChat;
  final VoidCallback onCopy;

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Pressable(
        onTap: widget.onTap,
        scale: 0.995,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 140),
          height: 72,
          padding: EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? AppColors.primary : AppColors.gray100,
            ),
          ),
          child: Row(
            children: [
              _StatusAvatar(member: member, size: 40),
              SizedBox(width: 14),
              SizedBox(
                width: 150,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title3.copyWith(fontSize: 16),
                      ),
                    ),
                    if (member.isMe) ...[SizedBox(width: 6), _MeTag()],
                  ],
                ),
              ),
              SizedBox(
                width: widget.showBranch ? 148 : 96,
                child: Text(
                  widget.showBranch
                      ? '${member.branchLabel} · ${member.role}'
                      : member.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
              _PermissionTag(permission: member.permission),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ),
              SizedBox(width: 12),
              SizedBox(width: 160, child: _StatusBadge(member: member)),
              SizedBox(width: 12),
              _ChatButton(onTap: widget.onChat),
              SizedBox(width: 8),
              _IconAction(
                icon: CupertinoIcons.doc_on_doc,
                onTap: widget.onCopy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 사내톡 열기 버튼
class _ChatButton extends StatelessWidget {
  _ChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        // 카드마다 있는 버튼이라 진한 파랑이면 화면이 파랗게 도배된다.
        // 연한 파랑 면에 파란 글씨로 눌러 둔다.
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_fill,
              size: 14,
              color: AppColors.primary,
            ),
            SizedBox(width: 6),
            Text(
              '메시지',
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 글자만 있는 작은 버튼
class _SmallButton extends StatelessWidget {
  _SmallButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            maxLines: 1,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.gray700,
            ),
          ),
        ),
      ),
    );
  }
}

/// 정사각 아이콘 버튼 (이메일 복사 등)
class _IconAction extends StatelessWidget {
  _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.92,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 15, color: AppColors.gray600),
      ),
    );
  }
}

/// 권한 꼬리표 — 관리 권한이 있는 사람만 파랗게
class _PermissionTag extends StatelessWidget {
  _PermissionTag({required this.permission});

  final Role permission;

  @override
  Widget build(BuildContext context) {
    final strong = permission.strong;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: strong ? AppColors.primaryLight : AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: strong ? Colors.transparent : AppColors.gray100,
        ),
      ),
      child: Text(
        permission.label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: strong ? AppColors.primary : AppColors.gray500,
        ),
      ),
    );
  }
}

/// 로그인한 사람 표시
class _MeTag extends StatelessWidget {
  _MeTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '나',
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// 카드 한 줄짜리 상태 표시
///
/// 재직자는 지금 무엇을 하는지, 대기자는 무엇을 기다리는지,
/// 퇴사자는 언제 나갔는지를 같은 자리에 보여준다.
class _StatusLine extends StatelessWidget {
  _StatusLine({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    if (member.employment == _Employment.left) {
      final at = member.resigned;
      // 서버가 퇴사일을 주기 전에 나간 사람은 날짜가 비어 있다
      return _line(
        AppColors.gray400,
        '퇴사',
        at == null ? '기록은 남아 있어요' : '${_date(at)}에 나갔어요',
      );
    }
    return _StatusBadge(member: member);
  }

  Widget _line(Color color, String label, String note) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      SizedBox(width: 7),
      Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      SizedBox(width: 6),
      Expanded(
        child: Text(
          '· $note',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(fontSize: 12),
        ),
      ),
    ],
  );
}

/// 상태 점 + 이름 (+ 상태 메시지)
class _StatusBadge extends StatelessWidget {
  _StatusBadge({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    final status = member.status;

    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: status.color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 7),
        Text(
          status.label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: status.color,
          ),
        ),
        if (member.note != null) ...[
          SizedBox(width: 6),
          Expanded(
            child: Text(
              '· ${member.note}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}
