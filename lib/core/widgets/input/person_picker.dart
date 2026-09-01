import 'package:flutter/material.dart';

import '../../data/staff.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../display/avatar.dart';
import '../feedback/app_dialog.dart';
import 'app_button.dart';
import 'pressable.dart';

/// 사람 한 칸 — 아바타 위, 이름 아래
///
/// **알약이 아니라 카드다** (2026-08-28). 알약은 이름 길이만큼 폭이 달라서
/// 줄이 들쭉날쭉했다 — 칸을 고정하면 세로 줄이 맞고 훑기가 쉽다.
///
/// 고른 것은 **테두리로** 가른다. 배경만으로는 `primaryLight`(옅은 파랑)와
/// `gray50`(옅은 회색)이 둘 다 옅어서 훑어서 안 잡힌다. 파랑을 꽉 채우지
/// 않는 이유는 안에 **색이 저마다 다른 아바타**가 있어서다 — 배경을 진하게
/// 하면 아바타가 묻힌다.
///
/// 프로젝트 생성 · 일정 · 회의록 · 인원 추가 신청이 **같은 칸을 쓴다.**
/// 예전에는 화면마다 제 것을 들고 있어서 하나를 고치면 나머지가 옛 모양으로
/// 남았다 (실제로 회의록만 알약으로 남아 있었다).
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.staff,
    required this.joined,
    this.onTap,
  });

  final Staff staff;
  final bool joined;

  /// null 이면 못 누른다 (본인·잠긴 폼) — **모양은 그대로 두고** 안 눌리게만 한다
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap ?? _ignore,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: joined ? AppColors.primaryLight : AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: joined ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(name: staff.name, size: 34),
            SizedBox(height: 7),
            // 칸 폭이 정해져 있어 긴 이름은 말줄임으로 자른다
            Text(
              staff.name == me ? '나' : staff.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: joined ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _ignore() {}
}

/// 한 줄에 셋씩 세운 사람 칸들
///
/// 폭을 [LayoutBuilder] 로 재서 나눈다 — 고정값으로 박으면 폰 폭이 다를 때
/// (SE·Max) 마지막 칸이 넘치거나 남는다.
class PersonGrid extends StatelessWidget {
  const PersonGrid({
    super.key,
    required this.people,
    required this.selected,
    required this.onToggle,
    this.locked = false,
  });

  final List<Staff> people;

  /// 고른 사람 이름 — 폼들이 아직 이름을 사람 키로 쓴다 (backend-gap 10번)
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  /// 잠긴 폼 — 모양은 그대로 두고 안 눌리게만 한다
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return PersonWrap(
      children: [
        // 명단 차례 그대로 — 누를 때마다 순서가 바뀌면 자리를 못 외운다
        for (final staff in people)
          PersonCard(
            staff: staff,
            joined: selected.contains(staff.name),
            onTap: locked ? null : () => onToggle(staff.name),
          ),
      ],
    );
  }
}

/// 사람 칸을 **한 줄에 셋씩** 세우는 판 — 칸 폭을 재서 나눈다
///
/// [PersonGrid](이름으로 여럿 고르기)와 **id 로 한 사람만 고르는 자리**
/// (기여 점수 주기)가 같이 쓴다. 칸 크기·간격이 화면마다 갈리면 안 된다 —
/// [PersonCard] 를 공용으로 만든 것과 같은 이유다.
///
/// 고정값으로 박으면 폰 폭이 다를 때(SE·Max) 마지막 칸이 넘치거나 남는다.
class PersonWrap extends StatelessWidget {
  const PersonWrap({super.key, required this.children});

  final List<Widget> children;

  static const _perRow = 3;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - _gap * (_perRow - 1)) / _perRow;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// 참석자를 고르는 창 — 취소하면 null, 완료하면 고른 이름들
///
/// **명단을 화면에 통째로 펴지 않는 자리**에 쓴다 (2026-08-28 대표 요청).
/// 회의록은 제목·날짜·프로젝트·본문이 한 화면에 다 있어서, 스무 명을 칸으로
/// 펴면 그것만으로 화면이 찬다. 프로젝트 생성처럼 폼이 한 페이지를 다 쓰는
/// 자리는 예전처럼 펴 두는 편이 낫다 — 창을 여닫는 품이 없다.
///
/// 이름을 다루는 것은 [PersonGrid] 와 같은 이유다 (backend-gap 10번).
Future<List<String>?> showPersonPicker(
  BuildContext context, {
  required List<Staff> people,
  required List<String> selected,
  String title = '참석자',
}) {
  return showAppDialog<List<String>>(
    context,
    (context) =>
        _PersonPickerCard(people: people, selected: selected, title: title),
  );
}

class _PersonPickerCard extends StatefulWidget {
  const _PersonPickerCard({
    required this.people,
    required this.selected,
    required this.title,
  });

  final List<Staff> people;
  final List<String> selected;
  final String title;

  @override
  State<_PersonPickerCard> createState() => _PersonPickerCardState();
}

class _PersonPickerCardState extends State<_PersonPickerCard> {
  late final _picked = widget.selected.toSet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dialogWidth(context, 400),
      padding: EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title, style: AppTextStyles.title2)),
              Text(
                '${_picked.length}',
                style: AppTextStyles.title2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // 명단이 스물이 넘으면 창이 화면을 넘는다 — 안에서 스크롤한다
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: PersonGrid(
                people: widget.people,
                selected: _picked,
                onToggle: (name) => setState(() {
                  if (!_picked.remove(name)) _picked.add(name);
                }),
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '취소',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: '완료',
                  filled: true,
                  // 명단 차례로 돌려준다 — 누른 차례로 주면 아바타 줄이
                  // 화면마다 다른 순서로 보인다
                  onTap: () => Navigator.pop(context, [
                    for (final staff in widget.people)
                      if (_picked.contains(staff.name)) staff.name,
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
