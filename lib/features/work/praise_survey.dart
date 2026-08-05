part of 'praise_section.dart';

// ── QR 설문 원본 ──

/// QR 설문으로 들어온 응답 한 건
///
/// 회원이 센터의 QR을 찍어 문항을 채워 보내면 그대로 쌓인다.
/// 칭찬·컴플레인 탭은 여기서 갈라 나온 것이고, '전체' 탭은 누구에게 온
/// 응답인지 가리지 않고 원본을 그대로 보여준다.
class _Survey {
  _Survey({
    required this.name,
    required this.phone,
    required this.colorValue,
    required this.motive,
    required this.praised,
    required this.improve,
    required this.time,
    this.consent = true,
  });

  /// 성함
  final String name;

  /// 연락처
  final String phone;
  final int colorValue;

  /// 운동을 시작하게 된 계기
  final String motive;

  /// 칭찬하고 싶은 직원 (안 적었으면 빈 값)
  final String praised;

  /// 개선했으면 하는 부분 (안 적었으면 빈 값)
  final String improve;

  /// 개인정보 수집 및 이용 동의
  final bool consent;

  final DateTime time;

  Color get color => Color(colorValue);
}

// 설문 목록(_surveys)은 위 _loadSurveys() 가 채운다.

/// '전체' 탭 카드 — 최근 설문 5건과 전체 보기 버튼
class _SurveyCard extends StatelessWidget {
  _SurveyCard({required this.onOpenAll});

  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final sorted = [..._surveys]..sort((a, b) => b.time.compareTo(a.time));
    final recent = sorted.take(5).toList();

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
                Text('설문 응답', style: AppTextStyles.label),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${sorted.length}',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                SeeAllButton(onTap: onOpenAll),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(4, 6, 4, 2),
            child: Text(
              'QR 설문으로 들어온 응답을 사람 구분 없이 모두 보여줘요',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
          SizedBox(height: 6),
          if (recent.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 22),
              child: Text(
                '아직 들어온 설문이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.divider),
              _SurveyRow(
                survey: recent[i],
                onTap: () => _showSurveyDetail(context, recent[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// 폰 설문 카드 — 피드백 카드와 같은 결
///
/// 데스크톱은 아직 [_SurveyRow] 를 쓴다 (2단 화면이라 카드가 과하다).
class _SurveyCardItem extends StatelessWidget {
  _SurveyCardItem({required this.survey, required this.onTap});

  final _Survey survey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: AppDecorations.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: survey.color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    survey.name.characters.first,
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
                      Text(
                        survey.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _formatStamp(survey.time),
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // 누구를 칭찬했는지 / 개선 요청만 남겼는지 한눈에
                if (survey.praised.isNotEmpty) ...[
                  SizedBox(width: 8),
                  _SurveyTag(
                    label: '칭찬 ${survey.praised}',
                    color: AppColors.primary,
                  ),
                ],
                if (survey.improve.isNotEmpty) ...[
                  SizedBox(width: 6),
                  _SurveyTag(label: '개선 요청', color: AppColors.warning),
                ],
              ],
            ),
            SizedBox(height: 14),
            Text(
              survey.motive,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 설문 한 줄 — 성함 · 칭찬한 직원 · 계기 미리보기
class _SurveyRow extends StatelessWidget {
  _SurveyRow({required this.survey, required this.onTap});

  final _Survey survey;
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
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: survey.color,
              shape: BoxShape.circle,
            ),
            child: Text(
              survey.name.characters.first,
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
                      survey.name,
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // 누구를 칭찬했는지 / 개선 요청만 남겼는지 한눈에
                    if (survey.praised.isNotEmpty) ...[
                      SizedBox(width: 6),
                      _SurveyTag(
                        label: '칭찬 ${survey.praised}',
                        color: AppColors.primary,
                      ),
                    ],
                    if (survey.improve.isNotEmpty) ...[
                      SizedBox(width: 6),
                      _SurveyTag(label: '개선 요청', color: AppColors.warning),
                    ],
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  survey.motive,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  _formatStamp(survey.time),
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
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
    );
  }
}

/// 설문 줄에 붙는 작은 꼬리표
class _SurveyTag extends StatelessWidget {
  _SurveyTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 설문 원본 크게 보기 — 받은 문항을 순서대로 그대로 보여준다
void _showSurveyDetail(BuildContext context, _Survey survey) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '설문 응답 크게 보기',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: _SurveyDetailCard(survey: survey),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SurveyDetailCard extends StatelessWidget {
  _SurveyDetailCard({required this.survey});

  final _Survey survey;

  @override
  Widget build(BuildContext context) {
    // 좁은 화면에서는 화면 폭에 맞춘다
    final width = MediaQuery.sizeOf(context).width - 40;

    return Container(
      width: width < 320 ? width : 320,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: survey.color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    survey.name.characters.first,
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 18,
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
                      Text(
                        survey.name,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _formatStamp(survey.time),
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 18),
            _SurveyField(label: '운동을 시작하게 된 계기', value: survey.motive),
            _SurveyField(label: '칭찬하고 싶은 직원', value: survey.praised),
            _SurveyField(label: '개선했으면 하는 부분', value: survey.improve),
            _SurveyField(
              label: '성함과 연락처',
              value: '${survey.name} · ${survey.phone}',
            ),
            _SurveyField(
              label: '개인정보 수집 및 이용 동의',
              value: survey.consent ? '동의함' : '동의하지 않음',
              valueColor: survey.consent ? AppColors.success : AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}

/// 문항 한 개 — 질문과 답변
class _SurveyField extends StatelessWidget {
  _SurveyField({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, 10, 12, 11),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              // 안 적고 넘어간 문항은 빈 칸으로 두지 않고 그렇다고 알려준다
              value.isEmpty ? '작성하지 않음' : value,
              style: AppTextStyles.body2.copyWith(
                fontSize: 13,
                height: 1.5,
                color:
                    valueColor ??
                    (value.isEmpty
                        ? AppColors.textTertiary
                        : AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 설문 전체 화면 — 날짜별로 묶고 아래 검색 바로 걸러 본다
class _SurveyHistoryScreen extends StatefulWidget {
  _SurveyHistoryScreen();

  @override
  State<_SurveyHistoryScreen> createState() => _SurveyHistoryScreenState();
}

class _SurveyHistoryScreenState extends State<_SurveyHistoryScreen> {
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

  /// 오늘/어제/그 외 날짜 라벨
  String _dayLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${time.month}.${time.day}';
  }

  bool _matches(_Survey survey, String query) {
    if (query.isEmpty) return true;
    return survey.name.contains(query) ||
        survey.phone.contains(query) ||
        survey.motive.contains(query) ||
        survey.praised.contains(query) ||
        survey.improve.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final sorted = _surveys.where((s) => _matches(s, query)).toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    // 날짜가 바뀌는 지점마다 그룹 헤더를 끼워 넣는다
    final children = <Widget>[];
    String? label;
    for (final survey in sorted) {
      final dayLabel = _dayLabel(survey.time);
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
        _SurveyRow(
          survey: survey,
          onTap: () => _showSurveyDetail(context, survey),
        ),
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
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'QR 설문으로 들어온 응답 전체',
                          style: AppTextStyles.caption,
                        ),
                      ),
                      Text(
                        '총 ${sorted.length}건',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                if (sorted.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 44),
                    child: Text(
                      query.isEmpty ? '아직 들어온 설문이 없어요' : '검색 결과가 없어요',
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
                  child: Text('설문 응답', style: AppTextStyles.title3),
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
          GlassSearchBar(controller: _search, hint: '이름·내용 검색'),
        ],
      ),
    );
  }
}
