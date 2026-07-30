import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 지점 직원 명단 (목업)
///
/// 아바타 색은 사내톡·동료 평가·프로젝트에서 같은 사람이 같은 색으로 보이도록
/// 여기 한 곳에서만 정한다. 실제 데이터 연동 시 이 목록을 서버 값으로 교체한다.
class Staff {
  const Staff(this.name, this.role, this.color);

  final String name;
  final String role;
  final Color color;
}

/// 로그인한 사람 (목업)
const me = '김은후';

const staffList = [
  Staff(me, '트레이너', AppColors.primary),
  Staff('이준승', '대표', Color(0xFF7C5CFC)),
  Staff('김피스', '개발', Color(0xFF00A8B5)),
  Staff('민중기', '점장', AppColors.success),
  Staff('박준현', '트레이너', AppColors.warning),
  Staff('유찬빈', '트레이너', Color(0xFF5C7CFA)),
  Staff('전상현', 'FC', Color(0xFFE0447C)),
];

/// 명단에 없는 이름이면 회색 아바타로 떨어진다
Staff staffOf(String name) => staffList.firstWhere(
  (s) => s.name == name,
  orElse: () => Staff(name, '', AppColors.gray400),
);
