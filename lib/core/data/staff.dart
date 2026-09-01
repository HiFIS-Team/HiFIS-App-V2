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
  const Staff(this.name, this.role, this.color, {this.imageUrl});

  final String name;
  final String role;
  final Color color;

  /// 프로필 사진 주소 — 없으면 null (첫 글자 동그라미로 떨어진다)
  ///
  /// 색과 **같은 길로** 둔다. 아바타를 그리는 자리가 56곳인데 사진을 넘겨주는
  /// 쪽은 4곳뿐이라, 랭킹·사내톡·프로젝트에서는 사진이 안 나왔다.
  /// 여기 담아 두면 [Avatar] 가 이름만 받고도 찾아 쓴다.
  final String? imageUrl;
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
/// 서버에서 받아온 명단이 전부다. **비어 있으면 비어 둔다.**
/// 예전엔 비면 가짜 이름 10명으로 떨어졌는데, 명단 로드가 한 번 실패하면
/// 사내톡·평가·결재 화면에 존재하지 않는 사람이 진짜처럼 떴다(그 사람을
/// 고르면 서버에서 404 로 막힐 뿐이다).
///
/// getter 인 이유는 두 가지다 — 명단을 받아오면 곧바로 반영돼야 하고,
/// 첫 줄이 로그인한 사람이라 [me]가 바뀌면 같이 바뀌어야 한다.
/// 상수로 두면 앱 시작 시점(로그아웃 상태)에 굳어 버린다.
List<Staff> get staffList => [
  for (final employee in StaffDirectory.instance.employees) staffFrom(employee),
];

/// 명단의 한 사람을 화면용 [Staff] 로 바꾼다
///
/// **[Employee] 를 손에 쥔 화면이 쓴다.** [staffOf] 는 이름으로 찾아서
/// 동명이인이 오면 엉뚱한 사람이 잡히는데, 여기는 그 사람 자체를 받는다.
Staff staffFrom(Employee employee) => Staff(
  employee.name,
  employee.rank.label,
  employee.color ?? avatarColorFor(employee.name),
  imageUrl: employee.avatarImageUrl,
);

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

/// 명단에 없는 이름이면 이름에서 만든 색을 쓴다
///
/// 아직 목업으로 도는 화면(프로젝트·공지·일정)의 이름들은 서버 명단에 없다.
/// 전부 회색으로 떨어뜨리면 화면이 죽어 보여서 색만 만들어 준다.
Staff staffOf(String name) => staffList.firstWhere(
  (s) => s.name == name,
  orElse: () => Staff(name, '', avatarColorFor(name)),
);
