import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'current_user.dart';
import 'employee.dart';
import 'staff_directory.dart';

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

/// 직원 명단
///
/// 서버에서 받아온 게 있으면 그걸 쓰고, 없으면 목업으로 떨어진다
/// (로그인 전이거나 서버가 꺼져 있을 때).
///
/// getter 인 이유는 두 가지다 — 명단을 받아오면 곧바로 반영돼야 하고,
/// 첫 줄이 로그인한 사람이라 [me]가 바뀌면 같이 바뀌어야 한다.
/// 상수로 두면 앱 시작 시점(로그아웃 상태)에 굳어 버린다.
List<Staff> get staffList {
  final employees = StaffDirectory.instance.employees;
  if (employees.isEmpty) return _mockStaffList;
  return [
    for (final employee in employees)
      Staff(
        employee.name,
        employee.rank.label,
        employee.color ?? avatarColorFor(employee.name),
      ),
  ];
}

/// 아바타 색을 이름에서 만든다
///
/// 서버 색이 없거나(`neutral`) 아직 명단에 없는 사람에게 쓴다.
/// 같은 이름이면 항상 같은 색이 나와야 사내톡·평가에서 사람이 안 헷갈린다.
/// `hashCode`는 실행마다 달라질 수 있어 글자 코드를 직접 더한다.
Color avatarColorFor(String name) {
  var sum = 0;
  for (final unit in name.codeUnits) {
    sum = (sum + unit) % 1000;
  }
  return _avatarPalette[sum % _avatarPalette.length];
}

const _avatarPalette = [
  AppColors.primary,
  AppColors.violet,
  AppColors.teal,
  AppColors.success,
  AppColors.warning,
  Color(0xFF5C7CFA),
  AppColors.pink,
  Color(0xFFB44BD9),
  Color(0xFF0F9BD7),
  Color(0xFFD9822B),
];

/// 서버 명단이 없을 때 쓰는 화면 확인용 명단
List<Staff> get _mockStaffList => [
  Staff(me, '트레이너', AppColors.primary),
  Staff('이준승', '대표', AppColors.violet),
  Staff('이준경', '개발', AppColors.teal),
  Staff('민중기', '점장', AppColors.success),
  Staff('박준현', '트레이너', AppColors.warning),
  Staff('유찬빈', '트레이너', Color(0xFF5C7CFA)),
  Staff('전상현', 'FC', AppColors.pink),
  Staff('문명진', '마케터', Color(0xFFB44BD9)),
  Staff('이지영', '트레이너', Color(0xFF0F9BD7)),
  Staff('김재훈', 'FC', Color(0xFFD9822B)),
];

/// 명단에 없는 이름이면 이름에서 만든 색을 쓴다
///
/// 아직 목업으로 도는 화면(프로젝트·공지·일정)의 이름들은 서버 명단에 없다.
/// 전부 회색으로 떨어뜨리면 화면이 죽어 보여서 색만 만들어 준다.
Staff staffOf(String name) => staffList.firstWhere(
  (s) => s.name == name,
  orElse: () => Staff(name, '', avatarColorFor(name)),
);
