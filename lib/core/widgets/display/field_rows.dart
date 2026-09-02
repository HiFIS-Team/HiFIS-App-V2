import 'package:flutter/cupertino.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../input/pressable.dart';

/// 인적 사항 한 줄의 재료
typedef FieldRow = ({String label, String value, VoidCallback? onCopy});

/// 이름표 칸 폭 — 제일 긴 것(`방문 경로`)에 맞춘다
///
/// 넓게 잡으면 값이 화면 가운데로 밀려서 왼쪽이 휑해진다.
const _labelWidth = 68.0;

/// 왼쪽 이름표 · 오른쪽 값으로 세운 줄들 — **사이에만 선을 긋는다**
///
/// 회원 정보와 운동일지가 **같은 부품을 쓴다.** 예전에는 파일마다 `_Field` 를
/// 따로 두었는데, 한쪽만 고치는 바람에 이름표 폭과 줄 높이가 갈렸다
/// (2026-09-02 대표 지적).
///
/// **마지막 줄 아래에는 선이 없다.** 있으면 카드 아래가 열린 것처럼 보이는데,
/// 메모처럼 있다 없다 하는 줄이 섞여서 손으로 붙이면 반드시 어긋난다.
class FieldRows extends StatelessWidget {
  const FieldRows({super.key, required this.fields});

  final List<FieldRow> fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < fields.length; i++)
          _Field(row: fields[i], last: i == fields.length - 1),
      ],
    );
  }
}

/// [FieldRows] 를 흰 카드에 담은 것 — 위아래 여백까지 맞춰 준다
class FieldCard extends StatelessWidget {
  const FieldCard({super.key, required this.fields});

  final List<FieldRow> fields;

  @override
  Widget build(BuildContext context) => Container(
    // 줄마다 세로 14 이 붙으므로 6 을 더하면 위아래가 20 씩으로 같아진다
    padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
    decoration: AppDecorations.card(),
    child: FieldRows(fields: fields),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.row, required this.last});

  final FieldRow row;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(
              row.label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.value,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (row.onCopy != null) ...[
            const SizedBox(width: 8),
            Icon(CupertinoIcons.doc_on_doc, size: 15, color: AppColors.gray400),
          ],
        ],
      ),
    );

    return Column(
      children: [
        if (row.onCopy case final onCopy?)
          Pressable(onTap: onCopy, child: line)
        else
          line,
        if (!last) Container(height: 1, color: AppColors.gray50),
      ],
    );
  }
}
