import 'dart:io';
import 'dart:typed_data';

import 'package:cupertino_native/cupertino_native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/api/client/api_client.dart';
import '../../../core/api/client/api_exception.dart';
import '../../../core/api/staff/staff_api.dart';
import '../../../core/api/work/draw_api.dart';
import '../../../core/data/staff.dart';
import '../../../core/data/staff_directory.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/platform.dart';
import '../../../core/util/reels_share.dart';
import '../../../core/util/sf_symbols.dart';
import '../../../core/util/skeleton_delay.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/delayed_spinner.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/feedback/skeleton.dart';
import '../../../core/widgets/glass/glass_bottom_button.dart';
import '../../../core/widgets/glass/glass_icon_button.dart';
import '../../../core/widgets/glass/glass_menu.dart';
import '../../../core/widgets/input/app_button.dart';
import '../../../core/widgets/input/mode_switch.dart';
import '../../../core/widgets/input/pressable.dart';
import '../../../core/widgets/nav/phone_scaffold.dart';

// ── 이번 달 추첨 · 영상 ──
//
// 설문을 낸 회원 중 셋을 뽑아 매장 TV 가 게임으로 굴려 보여준다. 그 게임을
// 서버가 세로 영상(1080×1920)으로 찍어 두는데, 여기서 그걸 **인스타 릴스
// 작성 화면으로 바로 보낸다** (2026-09-01 대표 요청).
//
// 캡션을 쓰고 올리는 것은 사람이 인스타 안에서 한다 — 우리가 대신 올리는 게
// 아니라서 심사가 없다 ([ReelsShare] 참고).
//
// **PC 는 파일로 저장한다** — 거기엔 인스타 앱이 없다.
//
// **권한을 안 가린다** (2026-09-01 대표 결정). 직원이 각자 자기 인스타에
// 올리는 것까지가 목적이라 대표만 여는 자리가 아니다. 지점은 서버가 가른다 —
// 직원·점장은 자기 지점 것만 온다.

/// 이 화면이 보여주는 두 가지 (2026-09-16 대표 요청)
///
/// **매장 TV 가 기본이다.** 대표·관리자는 매장에 없어서 벽에 지금 무엇이
/// 걸려 있는지를 볼 길이 없었다 — 직원·점장은 매장에서 그냥 보면 된다.
/// 추첨 영상은 한 달에 한 번 올리는 것이라 두 번째 자리가 맞다.
enum _Mode {
  tv('실시간 TV 화면', 'tv', CupertinoIcons.tv),
  video('추첨 영상', 'film', CupertinoIcons.film);

  const _Mode(this.label, this.symbol, this.icon);

  final String label;

  /// SF 심볼 이름 — **[sfSymbols] 매핑표에도 있어야 한다**
  /// (안 넣으면 안드로이드·윈도우에서 빈 원이 된다)
  final String symbol;

  /// 애플이 아닐 때 메뉴 줄에 붙는 아이콘
  final IconData icon;
}

/// 인스타그램 앱을 여는 주소 — 없으면 아무 일도 안 한다
/// 이번 달 추첨 — 당첨자와 게임 영상
class DrawScreen extends StatefulWidget {
  DrawScreen({super.key, this.branchId});

  /// 업무 화면 지점 고르개가 정한 지점 — null 이면 볼 수 있는 전부
  final String? branchId;

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen>
    with SkeletonDelay<DrawScreen> {
  List<MonthDraw> _draws = const [];

  /// 지금 내려받고 있는 추첨 — 그동안 버튼이 잠긴다
  String? _saving;

  /// 폰에서 보고 있는 지점 — [_branches] 의 몇 번째
  int _branch = 0;

  /// 그 지점 안에서 몇 번째 달 — 0 이 이번 달이다
  int _month = 0;

  /// 지금 보고 있는 것 — **대표·관리자는 매장 TV 로 시작한다**
  late _Mode _mode = _canSeeTv ? _Mode.tv : _Mode.video;

  /// TV 모드에서 보고 있는 지점 — [_tvBranches] 의 몇 번째
  int _tvBranch = 0;

  /// 지점 id → 매장 TV 주소. **한 번 받으면 다시 안 받는다** — 지점을
  /// 오가며 볼 때마다 부르면 같은 값을 계속 되묻는 셈이다
  final _tvUrls = <String, String>{};

  /// 주소를 못 받은 이유 — 받아 두면 화면이 빈 채로 멎지 않는다
  String? _tvError;

  /// **MASTER·ADMIN 만** (서버 `/tv-link` 도 같은 문이다).
  ///
  /// 직원·점장은 매장에서 벽을 그냥 보면 되고, 주소가 곧 그 지점 TV 의
  /// 열쇠라 전 직원에게 열 이유가 없다.
  bool get _canSeeTv => myRole.boss;

  @override
  void initState() {
    super.initState();
    _load();
    if (_mode == _Mode.tv) _loadTv();
  }

  /// 볼 수 있는 지점 — **추첨이 없는 지점도 세운다.**
  ///
  /// [_branches] 는 추첨에서 뽑은 것이라 이번 달 추첨이 없는 지점이 빠지는데,
  /// TV 는 추첨과 상관없이 늘 돌아간다.
  List<Branch> get _tvBranches {
    final directory = StaffDirectory.instance;
    final all = [...directory.branches.where((b) => !b.isHq)]
      ..sort(
        (a, b) =>
            directory.branchRank(a.id).compareTo(directory.branchRank(b.id)),
      );
    // 업무 헤더에서 지점을 골라 두었으면 그 하나만 — 두 자리에서 따로 고르면
    // 어느 쪽이 이긴 건지 알 수 없다
    final fixed = widget.branchId;
    if (fixed == null) return all;
    return all.where((b) => b.id == fixed).toList();
  }

  Branch? get _tvShown {
    final rows = _tvBranches;
    if (rows.isEmpty) return null;
    return rows[_tvBranch.clamp(0, rows.length - 1)];
  }

  /// 지금 고른 지점의 TV 주소를 받아 둔다 — 이미 있으면 아무 일도 안 한다
  Future<void> _loadTv() async {
    final branch = _tvShown;
    if (branch == null || _tvUrls.containsKey(branch.id)) return;
    try {
      final url = await BranchApi.tvLink(branch.id);
      if (!mounted) return;
      setState(() {
        _tvUrls[branch.id] = url;
        _tvError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _tvError = e.message);
    }
  }

  Future<void> _load() async {
    try {
      final rows = await DrawApi.list(branchId: widget.branchId);
      if (!mounted) return;
      setState(() {
        _draws = rows;
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 한 판의 열쇠 — 지점·달이 같은 추첨은 하나뿐이다
  String _keyOf(MonthDraw draw) => '${draw.branchId}:${draw.period}';

  /// 영상을 인스타로 넘긴다 — PC 는 파일로 저장한다
  Future<void> _send(MonthDraw draw) async {
    if (_saving != null || !draw.hasVideo) return;
    setState(() => _saving = _keyOf(draw));
    final name = '피트니스스타_${draw.branchName}_${draw.period}';
    try {
      final bytes = Uint8List.fromList(await DrawApi.video(draw.videoUrl!));
      if (!mounted) return;

      if (isDesktop) {
        final target = await FilePicker.saveFile(
          dialogTitle: '추첨 영상 저장',
          fileName: '$name.mp4',
          bytes: bytes,
        );
        if (mounted && target != null) AppToast.show(context, '영상을 저장했어요');
      } else {
        final file = await _writeTemp(bytes, name);
        // 시트가 안 뜨면 알린다 — 아무 일도 안 일어나면 고장으로 보인다
        if (!await ReelsShare.share(file.path) && mounted) {
          AppToast.show(context, '공유 화면을 열지 못했어요');
        }
      }
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _saving = null);
  }

  /// 넘겨줄 파일을 임시 자리에 쓴다 — **지난 것들을 먼저 치운다**
  ///
  /// 공유 시트가 읽어 가는 동안 지우면 안 돼서 넘긴 뒤 바로 못 지운다. 그래서
  /// **다음에 올 때** 치운다 — 안 그러면 폰에 영상이 달마다 쌓인다.
  /// `path_provider` 를 더 넣지 않으려고 시스템 임시 폴더를 쓴다 (앱 전용
  /// 자리라 다른 앱이 못 본다).
  Future<File> _writeTemp(Uint8List bytes, String name) async {
    final dir = Directory('${Directory.systemTemp.path}/reels');
    if (dir.existsSync()) {
      for (final old in dir.listSync()) {
        try {
          await old.delete();
        } catch (_) {
          // 인스타가 아직 들고 있을 수 있다 — 다음에 치우면 된다
        }
      }
    } else {
      dir.createSync(recursive: true);
    }
    final file = File('${dir.path}/$name.mp4');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// 지금 보고 있는 추첨 — 폰에서만 쓴다 (PC 는 목록을 다 세운다)
  MonthDraw? get _shown {
    final rows = _ofBranch;
    if (rows.isEmpty) return null;
    return rows[_month.clamp(0, rows.length - 1)];
  }

  /// 고른 지점의 추첨들 — 최신 달부터
  List<MonthDraw> get _ofBranch {
    if (_branches.length < 2) return _draws;
    final id = _branches[_branch.clamp(0, _branches.length - 1)];
    return _draws.where((d) => d.branchId == id).toList();
  }

  /// 볼 수 있는 지점들 — **화순 · 첨단** 차례
  ///
  /// 서버는 이름 가나다순(첨단·화순)으로 주는데, 앱에는 지점 차례가
  /// 따로 있다 ([StaffDirectory.branchRank]). 화면마다 다른 차례로 세우면
  /// 눈이 자리를 못 외운다 — 조직도·랭킹·업무 필터가 다 그 차례다.
  ///
  /// 직원·점장은 하나뿐이라 목록바가 안 뜬다. 대표·관리자가 '전 지점' 일 때만
  /// 여럿이다.
  List<String> get _branches {
    final out = <String>[];
    for (final d in _draws) {
      if (!out.contains(d.branchId)) out.add(d.branchId);
    }
    final dir = StaffDirectory.instance;
    out.sort((a, b) => dir.branchRank(a).compareTo(dir.branchRank(b)));
    return out;
  }

  String _branchName(String id) =>
      _draws.firstWhere((d) => d.branchId == id).branchName;

  /// 헤더 오른쪽 고르개 — **볼 것이 하나뿐이면 안 세운다**
  List<Widget> get _actions => _canSeeTv
      ? [
          _ModeButton(
            selected: _mode,
            onSelect: (mode) {
              setState(() => _mode = mode);
              if (mode == _Mode.tv) _loadTv();
            },
          ),
        ]
      : const [];

  @override
  Widget build(BuildContext context) {
    if (_mode == _Mode.tv) return _tv(context);

    // PC 는 목록 그대로 — 인스타 앱이 없어서 파일 저장까지다
    if (isDesktop) {
      return PhoneDetailScaffold(
        title: _Mode.video.label,
        actions: _actions,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            PhoneDetailScaffold.topPadding,
            20,
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          children: [
            showSkeleton
                ? SkeletonRows(rows: 3, avatar: 0, trailing: 0, gap: 22)
                : _list(),
          ],
        ),
      );
    }

    final draw = _shown;
    return PhoneDetailScaffold(
      title: _Mode.video.label,
      actions: _actions,
      // 리퀴드 글래스 하단 버튼 — 영상이 화면을 꽉 채우고 버튼이 그 위에 뜬다
      bottomBar: draw == null || !draw.hasVideo
          ? null
          : GlassBottomButton(
              label: '릴스 올리기',
              onPressed: _saving == null ? () => _send(draw) : () {},
              active: _saving == null,
            ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          // 글래스 버튼에 안 가리게 — 버튼이 없으면 평범한 여백
          draw != null && draw.hasVideo
              ? GlassBottomButton.inset(context)
              : MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: showSkeleton ? [_skeleton()] : _phone(draw),
      ),
    );
  }

  Widget _skeleton() => SkeletonGroup(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 히어로 자리 — 9:16 이라 화면 폭에서 높이가 나온다
        AspectRatio(aspectRatio: 9 / 16, child: Skeleton(radius: 20)),
        SizedBox(height: 16),
        Skeleton(width: 160, height: 13),
      ],
    ),
  );

  List<Widget> _phone(MonthDraw? draw) {
    if (draw == null) {
      return [EmptyCard(icon: Icons.movie_outlined, text: '아직 추첨한 달이 없어요')];
    }
    final rows = _ofBranch;
    return [
      // 지점이 여럿일 때만 — 대표·관리자가 '전 지점' 으로 볼 때다
      if (_branches.length > 1) ...[
        SegmentedTabs(
          labels: [for (final id in _branches) _branchName(id)],
          selected: _branch.clamp(0, _branches.length - 1),
          onSelect: (i) => setState(() {
            _branch = i;
            // 지점마다 있는 달이 다르다 — 첫 달로 되돌린다
            _month = 0;
          }),
        ),
        SizedBox(height: 16),
      ],
      // **키에 지점·달을 넣는다** — 안 넣으면 다른 달을 골라도 재생기가
      // 옛 영상을 그대로 들고 있다
      _Hero(key: ValueKey(_keyOf(draw)), draw: draw),
      SizedBox(height: 14),
      Text(
        '${draw.monthLabel} 추첨 · ${draw.gameLabel} · ${draw.entryCount}명 참가',
        textAlign: TextAlign.center,
        style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
      ),
      // 지난 달은 아래에 줄로 — 누르면 히어로가 바뀐다
      if (rows.length > 1) ...[
        SizedBox(height: 26),
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '지난 달',
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (var i = 1; i < rows.length; i++)
          Pressable(
            onTap: () => setState(() => _month = i),
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
                Text(
                  '${rows[i].monthLabel} · ${rows[i].gameLabel}',
                  style: AppTextStyles.body2,
                ),
                Spacer(),
                Text('${rows[i].entryCount}명', style: AppTextStyles.caption),
              ],
            ),
          ),
      ],
    ];
  }

  /// 매장 TV 판 — **웹 화면을 그대로 띄운다** (2026-09-16 대표 요청)
  ///
  /// 네이티브로 다시 그리지 않는다. 그 화면은 물리 게임 일곱 개를 포함한
  /// 3600줄짜리 React 라([HiFIS-Client-V2] `src/app/tv/[token]/`), 베끼면
  /// **매장 벽과 앱이 서로 다른 것을 보여주기 시작한다.**
  ///
  /// TV 는 세로(9:16) 기준으로 짜여 있어서 폰 화면에 그대로 맞는다.
  Widget _tv(BuildContext context) {
    final branch = _tvShown;
    final url = branch == null ? null : _tvUrls[branch.id];
    final rows = _tvBranches;
    return PhoneDetailScaffold(
      title: _Mode.tv.label,
      actions: _actions,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          // 업무 헤더에서 지점을 고르지 않았을 때만 — 골랐으면 하나뿐이다
          if (rows.length > 1) ...[
            SegmentedTabs(
              labels: [for (final b in rows) b.name],
              selected: _tvBranch.clamp(0, rows.length - 1),
              onSelect: (i) {
                setState(() => _tvBranch = i);
                _loadTv();
              },
            ),
            SizedBox(height: 16),
          ],
          if (branch == null)
            EmptyCard(icon: Icons.tv_outlined, text: '볼 수 있는 지점이 없어요')
          else if (_tvError != null)
            EmptyCard(icon: Icons.tv_outlined, text: _tvError!)
          else if (url == null)
            // 주소 한 줄을 받는 것이라 금방 온다 — 뼈대가 아니라 스피너다
            AspectRatio(
              aspectRatio: 9 / 16,
              child: Center(child: DelayedSpinner()),
            )
          else
            _TvView(key: ValueKey(url), url: url),
          SizedBox(height: 14),
          Text(
            // **지금 벽에 걸린 것과 같은 화면**이라는 걸 말해 준다 —
            // 안 적으면 앱이 따로 만든 요약으로 읽힌다
            isDesktop ? '매장에 걸려 있는 화면이에요' : '매장에 걸려 있는 화면 그대로예요',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    if (_draws.isEmpty) {
      return EmptyCard(icon: Icons.movie_outlined, text: '아직 추첨한 달이 없어요');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _draws.length; i++) ...[
          if (i > 0) SizedBox(height: 14),
          _DrawCard(
            draw: _draws[i],
            busy: _saving == _keyOf(_draws[i]),
            // 하나를 받는 동안 다른 카드도 잠근다 — 두 개를 같이 보내면
            // 어느 것이 인스타로 갔는지 알기 어렵다
            onSend: _saving == null ? () => _send(_draws[i]) : null,
          ),
        ],
      ],
    );
  }
}

/// 히어로 — 포스터를 크게 깔고 **누르면 그 자리에서 튼다**
///
/// 처음에는 포스터(영상 마지막 프레임)만 그린다. **열자마자 안 튼다** —
/// 9MB 를 화면 열 때마다 받게 되고, 대부분은 보지 않고 바로 올린다.
/// 누르면 그때 받아서 소리 없이 돌아간다.
///
/// **PC 에서는 안 쓴다** — 거기는 목록에서 파일 저장까지다. `video_player`
/// 가 윈도우를 지원 안 하는 것이 여기서는 걸림돌이 아닌 이유다.
class _Hero extends StatefulWidget {
  _Hero({super.key, required this.draw});

  final MonthDraw draw;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  VideoPlayerController? _player;

  /// 받아오는 중 — 첫 재생에만 잠깐 돈다
  bool _loading = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  /// 처음 누르면 받아서 틀고, 그다음부터는 멈췄다 다시 튼다
  Future<void> _toggle() async {
    if (!widget.draw.hasVideo || _loading) return;

    final player = _player;
    if (player != null) {
      setState(() {
        player.value.isPlaying ? player.pause() : player.play();
      });
      return;
    }

    setState(() => _loading = true);
    // 서명이 주소 안에 있어서 헤더 없이 바로 받아진다
    final next = VideoPlayerController.networkUrl(
      Uri.parse(fileUrl(widget.draw.videoUrl!)),
    );
    try {
      await next.initialize();
      await next.setLooping(true);
      // 영상에 소리가 아예 없다 — 화면 녹화라 음성 트랙을 안 담았다
      await next.play();
      if (!mounted) {
        await next.dispose();
        return;
      }
      // 재생 위치가 바뀔 때마다 다시 그린다 — 멈춤·재생 표시가 따라간다
      next.addListener(_onTick);
      setState(() {
        _player = next;
        _loading = false;
      });
    } catch (_) {
      await next.dispose();
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, '영상을 열지 못했어요');
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final draw = widget.draw;
    final poster = draw.posterUrl;
    final player = _player;
    final playing = player?.value.isPlaying ?? false;

    return Pressable(
      onTap: draw.hasVideo ? _toggle : () {},
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          // 릴스와 같은 세로 비율 — 올라갈 모양 그대로 보인다
          aspectRatio: 9 / 16,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: AppColors.gray100),
              // 포스터는 **재생 중에도 아래에 둔다** — 걷어내면 그 프레임 동안
              // 회색 판이 비쳐서 깜빡인다
              if (poster != null && poster.isNotEmpty)
                Image.network(
                  fileUrl(poster),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => SizedBox.shrink(),
                ),
              if (player != null) VideoPlayer(player),
              if (!draw.hasVideo)
                Center(
                  child: Text(
                    draw.winners.isEmpty
                        // 그달 설문이 한 건도 없던 지점이다
                        ? '그달에는 설문이 없어서\n추첨을 안 했어요'
                        // 매월 1일 아침에 굽는다 — 그 전이거나 굽다 실패한 달이다
                        : '영상을 만들고 있어요',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              else if (_loading)
                Center(child: DelayedSpinner())
              // **틀고 있으면 아무것도 안 얹는다** — 재생 중에 아이콘이 떠 있으면
              // 화면 한가운데를 가린다. 누르면 멈추고 그때 다시 나온다
              else if (!playing)
                Center(
                  child: Icon(
                    CupertinoIcons.play_circle_fill,
                    size: 62,
                    // 포스터가 밝아서 흰 아이콘은 묻힌다 — 어두운 쪽으로 둔다
                    color: AppColors.textPrimary.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 추첨 한 판 — 지점·게임·당첨자 셋과 영상 버튼
class _DrawCard extends StatelessWidget {
  _DrawCard({required this.draw, required this.busy, required this.onSend});

  final MonthDraw draw;
  final bool busy;
  final VoidCallback? onSend;

  /// 등수별 색 — 매장 TV 시상대(금·은·동)와 같은 결이다
  static const _medals = [
    Color(0xFFE8A33D),
    Color(0xFF9AA5B1),
    Color(0xFFC08552),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${draw.monthLabel} · ${draw.branchName}',
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              Text(
                '${draw.gameLabel} · ${draw.entryCount}명',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          SizedBox(height: 14),
          if (draw.winners.isEmpty)
            Text(
              '그달에는 설문이 없어서 추첨을 안 했어요',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textTertiary,
              ),
            )
          else
            for (final winner in draw.winners) ...[
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _medals[(winner.rank - 1).clamp(0, 2)],
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '${winner.rank}',
                        style: AppTextStyles.caption.copyWith(
                          // 금·은·동은 테마를 안 타는 고정색이라 글자도 고정이다
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      winner.name,
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          SizedBox(height: 4),
          if (draw.winners.isEmpty)
            SizedBox.shrink()
          else if (!draw.hasVideo)
            Text(
              // 매월 1일 아침에 굽는다 — 그 전이거나 굽다 실패한 달이다
              '영상을 만들고 있어요',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            )
          else
            AppButton(
              label: isDesktop ? '영상 저장' : '릴스 올리기',
              filled: true,
              busy: busy,
              onTap: onSend ?? () {},
            ),
        ],
      ),
    );
  }
}

/// 매장 TV 를 그리는 자리 — **폰은 웹뷰, PC 는 브라우저로 넘긴다**
///
/// `webview_flutter` 는 안드로이드·iOS 구현만 있다. PC 에서 부르면 그 자리에서
/// 죽으므로 아예 안 만든다 — 거기는 창이 크고 브라우저가 늘 있으니
/// 주소를 넘기는 쪽이 낫다 (운동일지 영상이 같은 판단을 한다).
class _TvView extends StatefulWidget {
  _TvView({super.key, required this.url});

  final String url;

  @override
  State<_TvView> createState() => _TvViewState();
}

class _TvViewState extends State<_TvView> {
  WebViewController? _web;

  @override
  void initState() {
    super.initState();
    if (isDesktop) return;
    _web = WebViewController()
      // 게임이 도는 화면이라 자바스크립트가 없으면 아무것도 안 그려진다
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // 웹 화면이 어두운 판을 직접 칠한다 — 그 뒤가 하얗게 비치면
      // 불러오는 동안 한 번 번쩍인다
      ..setBackgroundColor(const Color(0xFF101319))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    // TV 화면이 9:16 이라 폭에서 높이가 나온다 — 그래야 매장 벽과 같은 비율이다
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: isDesktop
            ? _openInBrowser(context)
            : WebViewWidget(controller: _web!),
      ),
    );
  }

  Widget _openInBrowser(BuildContext context) => ColoredBox(
    color: const Color(0xFF101319),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tv_outlined, size: 40, color: AppColors.gray400),
            SizedBox(height: 14),
            Text(
              'PC 에서는 브라우저로 열려요',
              textAlign: TextAlign.center,
              style: AppTextStyles.body2.copyWith(color: AppColors.gray300),
            ),
            SizedBox(height: 18),
            AppButton(
              label: '매장 TV 화면 열기',
              filled: true,
              shrinkWrap: true,
              onTap: () => launchUrl(
                Uri.parse(widget.url),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 헤더 오른쪽의 모드 고르개 — **실시간 TV 화면 · 추첨 영상**
///
/// 지점 고르개·랭킹 직군 필터와 같은 부품이다 — 아이폰은 OS 가 그리는
/// 네이티브 메뉴, 그 외는 [showGlassMenu]. **macOS 는 네이티브를 안 쓴다**
/// (같은 패키지가 메뉴를 버튼 왼쪽에 고정해서 창 밖으로 새어 나간다).
///
/// **`전체` 줄이 없다.** 저쪽 둘은 거르개라 안 거르는 상태가 있는데,
/// 여기는 둘 중 하나를 보는 자리다.
class _ModeButton extends StatefulWidget {
  _ModeButton({required this.selected, required this.onSelect});

  final _Mode selected;
  final ValueChanged<_Mode> onSelect;

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  /// 메뉴를 버튼 아래에 띄우려면 버튼 자리를 알아야 한다
  final _key = GlobalKey();

  /// 이미 떠 있는지 — 없으면 누를 때마다 하나씩 더 쌓인다
  bool _open = false;

  /// 버튼이 아이콘 하나라 **지금 무엇을 보고 있는지**를 아이콘으로 말한다.
  /// 다른 고르개처럼 `.fill` 로 가르지 않는다 — 안 고른 상태가 없어서
  /// 채운 아이콘이 늘 떠 있으면 뜻이 없다.
  String get _symbol => widget.selected.symbol;

  Future<void> _openMenu() async {
    if (_open) return;
    _open = true;
    final picked = await showGlassMenu<int>(
      context: context,
      anchorKey: _key,
      width: 200,
      items: [
        for (var i = 0; i < _Mode.values.length; i++)
          GlassMenuItem(
            value: i,
            label: _Mode.values[i].label,
            icon: _Mode.values[i].icon,
            selected: widget.selected == _Mode.values[i],
          ),
      ],
    );
    _open = false;
    if (!mounted || picked == null) return;
    widget.onSelect(_Mode.values[picked]);
  }

  @override
  Widget build(BuildContext context) {
    if (isApple && !isDesktop) {
      // 테마가 바뀌면 새로 만든다 (패키지의 setBrightness 가 아이콘을 유실).
      // **고른 모드는 키에 안 넣는다** — 넣으면 고를 때마다 뷰를 새로 만든다
      return CNPopupMenuButton.icon(
        key: ValueKey('draw-mode-${AppColors.isDark}'),
        buttonIcon: CNSymbol(_symbol, size: 16.8, color: AppColors.gray700),
        size: 40,
        items: [
          // 네이티브 메뉴에는 체크마크를 못 단다 — 고른 줄은 **아이콘 자리**가
          // 체크로 바뀐다
          for (final mode in _Mode.values)
            CNPopupMenuItem(
              label: mode.label,
              icon: CNSymbol(
                widget.selected == mode ? 'checkmark' : mode.symbol,
              ),
            ),
        ],
        onSelected: (index) => widget.onSelect(_Mode.values[index]),
      );
    }

    return GlassIconButton(
      key: _key,
      // 심볼이 바뀌어도 네이티브 버튼을 새로 만들지 않게 고정 식별자를 준다
      stableId: 'draw-mode',
      symbol: _symbol,
      onPressed: _openMenu,
    );
  }
}
