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
const me = '김피스';

/// 시스템 권한
///
/// 사람을 찾는 기준은 아니라서 직원 명단에서는 배지로만 쓰지만,
/// 기여 점수 부여처럼 아무나 하면 안 되는 기능이 이 값을 본다.
enum Permission {
  master('MASTER'),
  admin('ADMIN'),
  member('MEMBER');

  const Permission(this.label);

  final String label;

  /// 관리 권한 (MASTER·ADMIN) — 배지를 파랗게 칠한다
  bool get strong => this != Permission.member;

  /// 남에게 기여 점수를 줄 수 있는지 (마스터~매니저)
  bool get canGrant => strong;
}

/// 로그인한 사람의 권한 (목업)
///
/// 실제 연동 때는 로그인 응답에서 받아 온다.
/// 부여 화면을 확인하려면 여기를 [Permission.member]로 바꿔 보면 된다.
const myPermission = Permission.master;

const staffList = [
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
