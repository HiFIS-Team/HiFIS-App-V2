import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/glass_icon_button.dart';
import '../../core/widgets/pressable.dart';

/// 수업 개수 탭 콘텐츠 (목업)
///
/// 수업은 회원의 싸인을 받아야 인정된다.
/// - 내 회원: 등록된 회원 목록과 회원 등록, 회원별 싸인 받기
/// - 싸인 내역: 받은 싸인 기록 (서명 미리보기 포함)
class LessonSection extends StatefulWidget {
  LessonSection({super.key});

  @override
  State<LessonSection> createState() => _LessonSectionState();
}

/// 아바타 색 팔레트 — 새 회원 등록 시 순서대로 배정
const _palette = [
  Color(0xFF00A8B5),
  Color(0xFF7C5CFC),
  Color(0xFFE0447C),
  AppColors.success,
  AppColors.warning,
];

/// 등록된 회원 목록 (목업 초기값). 탭을 오가도 유지되도록 모듈 전역으로 둔다.
final _members = <_LessonMember>[
  _LessonMember(
    name: '박서연',
    color: _palette[0],
    total: 20,
    done: 12,
    price: 50000,
  ),
  _LessonMember(
    name: '최준영',
    color: _palette[1],
    total: 30,
    done: 8,
    price: 55000,
  ),
  _LessonMember(
    name: '한지우',
    color: _palette[2],
    total: 10,
    done: 9,
    price: 45000,
  ),
];

/// 1,000 단위 콤마 표기
String _comma(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// 받은 싸인 내역 (표시할 때 최신순 정렬)
final _signs = <_LessonSign>[..._seedSigns()];

List<_LessonSign> _seedSigns() {
  final now = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(now.year, now.month, now.day, hour, minute);
  const padSize = Size(300, 160);
  return [
    _LessonSign(
      member: '박서연',
      round: 12,
      time: at(9, 30),
      padSize: padSize,
      strokes: [
        [Offset(50, 100), Offset(80, 50), Offset(110, 105), Offset(140, 60)],
        [Offset(165, 55), Offset(195, 95), Offset(230, 58), Offset(255, 90)],
      ],
    ),
    _LessonSign(
      member: '한지우',
      round: 9,
      time: at(11, 0),
      padSize: padSize,
      strokes: [
        [Offset(60, 60), Offset(90, 100), Offset(120, 55), Offset(150, 95)],
        [Offset(175, 75), Offset(205, 75), Offset(240, 100)],
      ],
    ),
  ];
}

String _formatTime(DateTime time) {
  final period = time.hour < 12 ? '오전' : '오후';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$period $hour:$minute';
}

class _LessonSectionState extends State<LessonSection> {
  /// 이름·총 횟수·진행 회차·세션 단가를 입력받아 회원을 추가한다
  Future<void> _register() async {
    final nameController = TextEditingController();
    final countController = TextEditingController(text: '20');
    final roundController = TextEditingController(text: '0');
    final priceController = TextEditingController(text: '50000');
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('회원 등록'),
        content: Column(
          children: [
            SizedBox(height: 14),
            CupertinoTextField(
              controller: nameController,
              placeholder: '회원 이름',
              autofocus: true,
            ),
            SizedBox(height: 8),
            CupertinoTextField(
              controller: countController,
              placeholder: '총 수업 횟수',
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
            CupertinoTextField(
              controller: roundController,
              placeholder: '진행 회차 (이미 한 횟수)',
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
            CupertinoTextField(
              controller: priceController,
              placeholder: '세션 단가 (원)',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text('등록'),
          ),
        ],
      ),
    );
    final name = nameController.text.trim();
    final total = int.tryParse(countController.text.trim()) ?? 20;
    final round = int.tryParse(roundController.text.trim()) ?? 0;
    final price = int.tryParse(priceController.text.trim()) ?? 50000;
    nameController.dispose();
    countController.dispose();
    roundController.dispose();
    priceController.dispose();
    if (ok != true || name.isEmpty || !mounted) return;
    setState(() {
      _members.add(
        _LessonMember(
          name: name,
          color: _palette[_members.length % _palette.length],
          total: total,
          done: round.clamp(0, total),
          price: price,
        ),
      );
    });
    AppToast.show(context, '$name님이 등록되었습니다');
  }

  Future<void> _requestSign(_LessonMember member) async {
    await Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => _SignScreen(member: member)),
    );
    // 싸인 화면에서 기록이 추가됐을 수 있으니 갱신한다
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [_buildMemberCard(), SizedBox(height: 16), _buildSignCard()],
    );
  }

  Widget _buildMemberCard() {
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
                Expanded(child: Text('내 회원', style: AppTextStyles.label)),
                // 새 회원 등록 버튼
                Pressable(
                  onTap: _register,
                  scale: 0.94,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.person_add,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 5),
                        Text(
                          '회원 등록',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          for (var i = 0; i < _members.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider),
            _MemberRow(
              member: _members[i],
              onSign: () => _requestSign(_members[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignCard() {
    final sorted = List.of(_signs)..sort((a, b) => b.time.compareTo(a.time));

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
                Expanded(child: Text('싸인 내역', style: AppTextStyles.label)),
                Text(
                  '총 ${_signs.length}건',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          if (sorted.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 22),
              child: Text(
                '아직 받은 싸인이 없어요',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            )
          else
            for (var i = 0; i < sorted.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.divider),
              _SignRow(sign: sorted[i]),
            ],
        ],
      ),
    );
  }
}

/// 등록된 회원 한 명
class _LessonMember {
  _LessonMember({
    required this.name,
    required this.color,
    required this.total,
    required this.price,
    this.done = 0,
  });

  final String name;
  final Color color;

  /// 등록한 총 수업 횟수
  final int total;

  /// 세션(1회) 단가, 원
  final int price;

  /// 싸인으로 확인된 진행 회차 — 싸인 한 번에 1회차씩 올라간다
  int done;
}

/// 싸인 기록 한 건
class _LessonSign {
  _LessonSign({
    required this.member,
    required this.round,
    required this.time,
    required this.strokes,
    required this.padSize,
  });

  final String member;

  /// 몇 회차 수업인지
  final int round;
  final DateTime time;

  /// 서명 획 좌표 (패드 좌표계)
  final List<List<Offset>> strokes;

  /// 서명 당시 패드 크기 — 미리보기 비율 맞춤에 사용
  final Size padSize;
}

/// 회원 한 줄 — 아바타·이름·진행 현황과 싸인 받기 버튼
class _MemberRow extends StatelessWidget {
  _MemberRow({required this.member, required this.onSign});

  final _LessonMember member;
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
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
                Text(
                  member.name,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'PT ${member.total}회 중 ${member.done}회 · 회당 ${_comma(member.price)}원',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Pressable(
            onTap: onSign,
            scale: 0.93,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '싸인 받기',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 싸인 내역 한 줄 — 서명 미리보기, 회원·회차, 시각
class _SignRow extends StatelessWidget {
  _SignRow({required this.sign});

  final _LessonSign sign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          // 서명 미리보기
          Container(
            width: 64,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomPaint(
              painter: _SignPainter(
                strokes: sign.strokes,
                sourceSize: sign.padSize,
                color: AppColors.textPrimary,
                strokeWidth: 1.4,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sign.member} · ${sign.round}회차',
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '수업 확인 완료',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(_formatTime(sign.time), style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// 싸인 받기 화면 — 회원이 손가락으로 서명하고 완료를 누르면 기록된다
class _SignScreen extends StatefulWidget {
  _SignScreen({required this.member});

  final _LessonMember member;

  @override
  State<_SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<_SignScreen> {
  final List<List<Offset>> _strokes = [];

  /// 완료 시 기록에 남길 패드 크기
  Size _padSize = Size.zero;

  bool get _signed => _strokes.any((stroke) => stroke.length > 1);

  void _clear() => setState(_strokes.clear);

  void _complete() {
    if (!_signed) {
      AppToast.show(context, '먼저 싸인을 받아주세요');
      return;
    }
    final member = widget.member;
    member.done += 1;
    _signs.add(
      _LessonSign(
        member: member.name,
        round: member.done,
        time: DateTime.now(),
        strokes: [for (final stroke in _strokes) List.of(stroke)],
        padSize: _padSize,
      ),
    );
    AppToast.show(context, '${member.name}님 ${member.done}회차 수업이 기록되었습니다');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

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
                          '${member.done + 1}회차 수업 확인',
                          style: AppTextStyles.caption,
                        ),
                      ),
                      // 다시 쓰기
                      Pressable(
                        onTap: _clear,
                        scale: 0.93,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray50,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.arrow_counterclockwise,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 5),
                              Text(
                                '다시 쓰기',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.gray100),
                // 서명 패드 — 남은 화면을 채운다
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      MediaQuery.paddingOf(context).bottom + 96,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _padSize = constraints.biggest;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: GestureDetector(
                            onPanStart: (d) =>
                                setState(() => _strokes.add([d.localPosition])),
                            onPanUpdate: (d) => setState(
                              () => _strokes.last.add(d.localPosition),
                            ),
                            child: Container(
                              color: AppColors.gray50,
                              child: Stack(
                                children: [
                                  if (!_signed)
                                    Center(
                                      child: Text(
                                        '여기에 싸인해주세요',
                                        style: AppTextStyles.body1.copyWith(
                                          color: AppColors.gray400,
                                        ),
                                      ),
                                    ),
                                  CustomPaint(
                                    size: Size.infinite,
                                    painter: _SignPainter(
                                      strokes: _strokes,
                                      color: AppColors.textPrimary,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
                  child: Text('${member.name} 싸인', style: AppTextStyles.title3),
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
          // 하단 고정: 네이티브 리퀴드 글래스 완료 버튼
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: CNButton(
                        // 테마 전환 시 설정 유실 버그 회피용 재생성 키
                        key: ValueKey('sign-done-${AppColors.isDark}'),
                        label: '싸인 완료',
                        // 서명 전에는 글래스, 서명하면 파란 프로미넌트 글래스.
                        // 비활성화하면 iOS가 글래스 재질을 빼버려서 항상 활성으로
                        // 두고, 미서명 시 동작은 _complete에서 무시한다.
                        style: _signed
                            ? CNButtonStyle.prominentGlass
                            : CNButtonStyle.glass,
                        tint: AppColors.primary,
                        height: 56,
                        onPressed: _complete,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 서명 획을 그리는 페인터 — sourceSize가 있으면 미리보기용으로 비율 축소
class _SignPainter extends CustomPainter {
  _SignPainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
    this.sourceSize,
  });

  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;
  final Size? sourceSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final source = sourceSize;
    if (source != null && source.width > 0 && source.height > 0) {
      final scale = (size.width / source.width) < (size.height / source.height)
          ? size.width / source.width
          : size.height / source.height;
      // 축소 후 가운데 정렬
      canvas.translate(
        (size.width - source.width * scale) / 2,
        (size.height - source.height * scale) / 2,
      );
      canvas.scale(scale);
    }

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignPainter oldDelegate) => true;
}
