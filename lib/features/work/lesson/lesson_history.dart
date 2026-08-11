part of 'lesson_section.dart';

/// 세션 기록 전체 화면 — 달을 넘겨 가며 날짜별로 묶어 보여준다
///
/// 싸인은 달마다 따로 받는다. 한 번에 다 받으면 해가 갈수록
/// 화면 열 때마다 몇 백 건씩 넘어온다.
class _SignHistoryScreen extends StatefulWidget {
  @override
  State<_SignHistoryScreen> createState() => _SignHistoryScreenState();
}

class _SignHistoryScreenState extends State<_SignHistoryScreen> {
  final _search = TextEditingController();

  late DateTime _month;
  List<SessionSign> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _search.addListener(() => setState(() {}));
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 다음 달로 못 넘어간다 — 아직 오지 않은 달이라 볼 게 없다
  bool get _atLatest {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final rows = await SessionSignApi.list(
        trainerId: currentUser?.id,
        period: periodKey(_month),
      );
      if (!mounted) return;
      setState(() {
        _rows = _LessonStore.instance.sorted(rows);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, messageOf(error));
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _fetch();
  }

  /// 오늘/어제/그 외 날짜 라벨
  String _dayLabel(DateTime time) => dayLabel(time);

  @override
  Widget build(BuildContext context) {
    final all = _rows;
    final query = _search.text.trim();
    final sorted = all
        .where((s) => query.isEmpty || s.displayName.contains(query))
        .toList();

    // 날짜가 바뀌는 지점마다 그룹 헤더를 끼워 넣는다
    final children = <Widget>[];
    String? label;
    for (final sign in sorted) {
      final dayLabel = _dayLabel(sign.signedAt);
      if (dayLabel != label) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, label == null ? 4 : 22, 4, 4),
            child: Text(
              dayLabel,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        label = dayLabel;
      } else {
        children.add(Divider(height: 1, color: AppColors.divider));
      }
      children.add(
        _SignRow(sign: sign, onTap: () => _showSignDetail(context, sign)),
      );
    }

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
                _MonthBar(
                  month: _month,
                  count: sorted.length,
                  loading: _loading,
                  onPrev: () => _shiftMonth(-1),
                  // 아직 오지 않은 달은 볼 게 없으니 막는다
                  onNext: _atLatest ? null : () => _shiftMonth(1),
                ),
                Container(height: 1, color: AppColors.gray100),
                if (_loading)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: SkeletonGroup(
                      child: SkeletonRows(rows: 5, trailing: 56),
                    ),
                  )
                else if (sorted.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                    child: Text(
                      all.isEmpty ? '이 달에 받은 싸인이 없어요' : '검색 결과가 없어요',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        8,
                        20,
                        // 하단 글래스 검색 바에 가리지 않도록 여유를 둔다
                        MediaQuery.paddingOf(context).bottom + 96,
                      ),
                      children: children,
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
                  child: Text('세션 기록', style: AppTextStyles.title3),
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
