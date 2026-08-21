part of 'lesson_section.dart';

/// 싸인 받을 회원 선택 화면
///
/// 내 담당 회원만 나온다. 남의 회원 싸인을 대신 받으면 서버가 커미션과
/// 수업왕 점수를 **수행한 사람** 기준으로 붙여서 매출 귀속이 어긋난다.
/// 우리는 대타로 수업하는 일이 없다.
class _PickMemberScreen extends StatefulWidget {
  @override
  State<_PickMemberScreen> createState() => _PickMemberScreenState();
}

class _PickMemberScreenState extends State<_PickMemberScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_LessonMember> get _filtered {
    final base = _LessonStore.instance.myMembers;
    final query = _search.text.trim();
    if (query.isEmpty) return base;
    return base.where((m) => m.name.contains(query)).toList();
  }

  /// 회원을 누르면 바로 서명 화면으로 이동한다
  ///
  /// 선택 화면이 PC에서 모달이라 서명도 모달로 겹쳐 띄운다.
  /// (여기서 push를 쓰면 모달 밖 루트로 나가 창 전체를 덮는다)
  Future<void> _open(_LessonMember member) async {
    if (!member.canSign) {
      AppToast.show(
        context,
        member.registration == null
            ? '${member.name}님은 등록권이 없어요. 먼저 등록해주세요'
            : '${member.name}님은 남은 회차가 없어요. 재등록이 필요해요',
      );
      return;
    }

    final done = await showFullPage<bool>(
      context,
      (_) => _SignScreen(member: member),
    );
    // 싸인을 받았으면 선택 화면도 닫고 업무 탭으로 돌아간다
    if (done == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 상단 고정 타이틀 영역만큼 비워둔다
                SizedBox(height: 56),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Text(
                    '내 담당 회원 ${list.length}명',
                    style: AppTextStyles.caption,
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      MediaQuery.paddingOf(context).bottom + 96,
                    ),
                    children: [
                      if (list.isEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(4, 10, 4, 10),
                          child: Text(
                            _search.text.trim().isEmpty
                                ? '등록된 회원이 없어요'
                                : '검색 결과가 없어요',
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      else
                        for (final member in list) ...[
                          _PickRow(member: member, onTap: () => _open(member)),
                          SizedBox(height: 8),
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
                  child: Text('세션 싸인 받기', style: AppTextStyles.title3),
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
          // 하단 고정: 플로팅 글래스 검색 바 (키보드와 함께 상승)
          GlassSearchBar(controller: _search, hint: '회원 이름 검색'),
        ],
      ),
    );
  }
}

/// 싸인 받을 회원 한 줄 — 누르면 바로 서명 화면으로 이동
class _PickRow extends StatelessWidget {
  _PickRow({required this.member, required this.onTap});

  final _LessonMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasRegistration = member.registration != null;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: member.color,
                shape: BoxShape.circle,
              ),
              child: Text(
                member.name.characters.first,
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
                        member.name,
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (hasRegistration) ...[
                        SizedBox(width: 6),
                        _MemberBadge(isNew: member.isNew),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    hasRegistration
                        ? '${member.done}/${member.total}회차 사용'
                        : '등록권 없음',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            // 남은 회차 배지
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: member.canSign
                    ? AppColors.gray100
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                member.canSign ? '${member.remaining}회 남음' : '재등록 필요',
                style: AppTextStyles.caption.copyWith(
                  color: member.canSign
                      ? AppColors.textSecondary
                      : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: AppColors.gray300,
            ),
          ],
        ),
      ),
    );
  }
}
