part of 'ranking_screen.dart';

// ---------------------------------------------------------------------------
// 항목 · 지점 고르기
// ---------------------------------------------------------------------------

/// 폰 항목 탭 — 밑줄 탭 (업무 탭과 같은 결)
///
/// 알약을 늘어놓으면 화면 폭을 넘겨 옆으로 밀어야 하는데,
/// 항목이 몇 개인지 한눈에 안 보인다. 한 화면에 다 세운다.
///
/// **칸을 6등분하지 않는다.** 등분하면 글자 길이가 달라서 남는 여백이
/// 칸마다 달라진다 — `프로젝트`·`환경정비`(4자)는 칸을 꽉 채워 서로 붙고,
/// `매출`·`친절`(2자)은 양옆이 남아 멀어 보였다 (실제로 그렇게 보였다).
/// **칸 = 글자 폭 + 똑같은 여백**으로 잡으면 어느 두 글자 사이든 간격이 같다.
/// 칸끼리는 여전히 붙어 있어서 **밑줄은 지금처럼 한 줄로 이어진다.**
class _PhoneTabs extends StatelessWidget {
  _PhoneTabs({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  /// 글자 위에 두는 여백 — 밑줄까지의 거리
  static const _bottom = 10.0;

  @override
  Widget build(BuildContext context) {
    final labels = [for (final metric in _Metric.values) metric.short];
    final scaler = MediaQuery.textScalerOf(context);
    final textWidths = [
      // **늘 굵게** 잰다 — 고른 칸만 굵어지는데 그때그때 재면 탭을 옮길
      // 때마다 칸 폭이 달라져서 글자들이 좌우로 흔들린다
      for (final label in labels) measureLabel(context, label, bold: true),
    ];
    final textTotal = textWidths.fold<double>(0, (sum, w) => sum + w);
    final line = TextPainter(
      text: TextSpan(text: '가', style: segmentTextStyle(selected: true)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();

    return LayoutBuilder(
      builder: (context, box) {
        // 글자만으로도 폭이 모자라면(글자 크기를 크게 키운 기기) 예전처럼 등분한다.
        // 그때는 `FittedBox` 가 줄여서 맞춘다 — 넘쳐서 잘리는 것보다 낫다.
        final gap = (box.maxWidth - textTotal) / labels.length;
        final even = gap <= 0;
        // 칸마다의 폭 — 마지막 칸은 남는 폭을 그대로 받는다. 소수점이 쌓여
        // 1px 넘치면 줄이 통째로 빨간 넘침 줄무늬가 된다
        final cells = <double>[];
        for (var i = 0; i < labels.length; i++) {
          if (i == labels.length - 1) {
            cells.add(box.maxWidth - cells.fold<double>(0, (a, b) => a + b));
          } else {
            cells.add(
              even ? box.maxWidth / labels.length : textWidths[i] + gap,
            );
          }
        }
        final index = selected.clamp(0, labels.length - 1);
        var left = 0.0;
        for (var i = 0; i < index; i++) {
          left += cells[i];
        }

        return SizedBox(
          height: line.height + _bottom + 2,
          child: Stack(
            children: [
              // 회색 밑줄은 **한 줄로 쭉** 이어진다 — 예전에는 칸마다 그렸다
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 2, color: AppColors.gray100),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    SizedBox(width: cells[i], child: _tab(i, labels[i])),
                ],
              ),
              // 파란 줄 **하나**가 미끄러진다 (2026-08-21 대표 요청).
              // 목록바가 도는 자리는 다 같은 빠르기를 쓴다 (`slideDuration`)
              AnimatedPositioned(
                duration: slideDuration,
                curve: slideCurve,
                left: left,
                width: cells[index],
                bottom: 0,
                child: Container(height: 2, color: AppColors.primary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tab(int i, String label) {
    return Pressable(
      onTap: () => onSelect(i),
      child: Padding(
        padding: EdgeInsets.only(bottom: _bottom + 2),
        child: Center(
          // 칸보다 이름이 길면 줄여서 맞춘다 (칸을 등분으로 되돌린 경우)
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: segmentTextStyle(selected: i == selected),
            ),
          ),
        ),
      ),
    );
  }
}

/// 직군 고르개 — 헤더 왼쪽의 **리퀴드 글래스 필터**
///
/// 트레이너와 FC 를 한 줄에 세우면 매출 비교가 뜻이 없어서 붙였다.
/// 하나 고르면 **그 직군끼리 다시 줄 세운다** — 시상대·내 순위·종합 환산이
/// 다 같은 목록을 보므로 등수가 그 안에서 매겨진다.
///
/// 메뉴는 **지점 고르개([BranchScopeButton])와 같은 부품**이다 — 아이폰은
/// OS 가 그리는 네이티브 메뉴, 그 외는 [showGlassMenu]. 두 버튼이 한 화면에
/// 뜨는데 유리 느낌이 다르면 티가 난다.
///
/// | | 어디에 |
/// |---|---|
/// | 폰 | 왼쪽 위 ([PhoneListScaffold.leading]) — 스크롤과 따로 떠 있는 자리 |
/// | 데스크톱 | 머리말 오른쪽 끝 (제목 앞에 버튼을 두면 어색하다) |
class _JobFilterButton extends StatefulWidget {
  _JobFilterButton({required this.selected, required this.onSelect});

  /// null 이면 '전체'
  final Rank? selected;
  final ValueChanged<Rank?> onSelect;

  @override
  State<_JobFilterButton> createState() => _JobFilterButtonState();
}

class _JobFilterButtonState extends State<_JobFilterButton> {
  /// 메뉴를 버튼 아래에 띄우려면 버튼 자리를 알아야 한다
  final _key = GlobalKey();

  /// 이미 떠 있는지 — 없으면 누를 때마다 하나씩 더 쌓인다
  bool _open = false;

  static const _allLabel = '전체';

  /// 걸려 있으면 채운 아이콘 — 버튼이 아이콘 하나라 고른 직군 **이름**은
  /// 메뉴를 열어야 보인다. 최소한 "지금 걸려 있다"는 건 알 수 있게 한다.
  String get _symbol => widget.selected == null
      ? 'line.3.horizontal.decrease'
      : 'line.3.horizontal.decrease.circle.fill';

  Future<void> _openMenu() async {
    if (_open) return;
    _open = true;
    final picked = await showGlassMenu<int>(
      context: context,
      anchorKey: _key,
      width: 200,
      // 왼쪽 위 버튼이라 메뉴도 왼쪽에 맞춘다 (기본값은 오른쪽 정렬)
      alignRight: false,
      items: [
        GlassMenuItem(
          // null 은 '안 골랐다'와 구분이 안 돼서 전체에 따로 값을 준다
          value: -1,
          label: _allLabel,
          icon: CupertinoIcons.square_grid_2x2,
          selected: widget.selected == null,
        ),
        for (var i = 0; i < _rankingJobs.length; i++)
          GlassMenuItem(
            value: i,
            label: _rankingJobs[i].label,
            icon: CupertinoIcons.person,
            selected: widget.selected == _rankingJobs[i],
          ),
      ],
    );
    _open = false;
    if (!mounted || picked == null) return;
    widget.onSelect(picked == -1 ? null : _rankingJobs[picked]);
  }

  @override
  Widget build(BuildContext context) {
    // 아이폰은 OS 가 그리는 네이티브 메뉴 — 지점 고르개와 같은 부품이다.
    // **macOS 는 안 쓴다** — 같은 패키지가 메뉴를 버튼 왼쪽에 고정해서
    // 창 밖으로 새어 나간다 (지점 고르개와 같은 이유).
    if (isApple && !isDesktop) {
      // 테마가 바뀌면 새로 만든다 — 패키지의 setBrightness 가 아이콘 설정을
      // 유실한다. **고른 직군은 키에 안 넣는다** (넣으면 고를 때마다 네이티브
      // 뷰를 새로 만든다).
      return CNPopupMenuButton.icon(
        key: ValueKey('ranking-job-${AppColors.isDark}'),
        buttonIcon: CNSymbol(_symbol, size: 16.8, color: AppColors.gray700),
        size: 40,
        items: [
          // 네이티브 메뉴에는 체크마크를 못 단다 — 고른 줄은 **아이콘 자리**가
          // 체크로 바뀐다 (지점 고르개와 같다).
          CNPopupMenuItem(
            label: _allLabel,
            icon: CNSymbol(
              widget.selected == null ? 'checkmark' : 'square.grid.2x2',
            ),
          ),
          for (final job in _rankingJobs)
            CNPopupMenuItem(
              label: job.label,
              icon: CNSymbol(widget.selected == job ? 'checkmark' : 'person'),
            ),
        ],
        onSelected: (index) =>
            widget.onSelect(index == 0 ? null : _rankingJobs[index - 1]),
      );
    }

    return GlassIconButton(
      key: _key,
      // 심볼이 바뀌어도 네이티브 버튼을 새로 만들지 않게 고정 식별자를 준다
      stableId: 'ranking-job',
      symbol: _symbol,
      onPressed: _openMenu,
    );
  }
}
