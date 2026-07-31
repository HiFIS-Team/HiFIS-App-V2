import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'current_user.dart';
import 'employee.dart';

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

/// 로그인한 사람의 이름
///
/// 아직 목업 화면들이 이름 문자열을 사람 키로 쓰고 있어서 이렇게 노출한다.
/// uuid 기준으로 바꾸는 건 별도 작업이다 (backend-gap.md 10번).
/// 로그인 전에는 목업 이름으로 떨어진다 — 로그인 화면 말고는 볼 일이 없다.
String get me => currentUser?.name ?? '김피스';

/// 로그인한 사람의 권한
Role get myRole => currentUser?.role ?? Role.member;

/// 첫 줄이 로그인한 사람이라 [me]가 바뀌면 같이 바뀌어야 한다.
/// 상수로 두면 앱 시작 시점의 이름(로그아웃 상태)에 굳어 버린다.
List<Staff> get staffList => [
  Staff(me, '트레이너', AppColors.primary),
  Staff('이준승', '대표', Color(0xFF7C5CFC)),
  Staff('이준경', '개발', Color(0xFF00A8B5)),
  Staff('민중기', '점장', AppColors.success),
  Staff('박준현', '트레이너', AppColors.warning),
  Staff('유찬빈', '트레이너', Color(0xFF5C7CFA)),
  Staff('전상현', 'FC', Color(0xFFE0447C)),
  Staff('문명진', '마케터', Color(0xFFB44BD9)),
  Staff('이지영', '트레이너', Color(0xFF0F9BD7)),
  Staff('김재훈', 'FC', Color(0xFFD9822B)),
];

/// 명단에 없는 이름이면 회색 아바타로 떨어진다
Staff staffOf(String name) => staffList.firstWhere(
  (s) => s.name == name,
  orElse: () => Staff(name, '', AppColors.gray400),
);
