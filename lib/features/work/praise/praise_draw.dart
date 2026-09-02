import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/work/draw_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/platform.dart';
import '../../../core/util/reels_share.dart';
import '../../../core/util/skeleton_delay.dart';
import '../../../core/widgets/feedback/app_toast.dart';
import '../../../core/widgets/feedback/empty_card.dart';
import '../../../core/widgets/feedback/skeleton.dart';
import '../../../core/widgets/input/app_button.dart';
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

  /// 지금 내려받고 있는 추첨 — 버튼 하나만 스피너가 된다
  String? _saving;

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    final body = showSkeleton
        ? SkeletonRows(rows: 3, avatar: 0, trailing: 0, gap: 22)
        : _list();

    return PhoneDetailScaffold(
      title: '추첨 영상',
      child: ListView(
        // 밀려 들어온 화면이라 **하단바를 덮는다** — `bottomBarInset` 을 쓰면
        // 있지도 않은 바만큼 아래가 헛되게 빈다 (출퇴근 QR 화면과 같은 값)
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [body],
      ),
    );
  }

  Widget _list() {
    if (_draws.isEmpty) {
      return EmptyCard(icon: Icons.emoji_events_rounded, text: '아직 추첨한 달이 없어요');
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
