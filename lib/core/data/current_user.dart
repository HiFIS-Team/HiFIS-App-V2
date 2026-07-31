import 'employee.dart';

/// 로그인한 직원
///
/// `AuthSession`이 로그인·복원 때 채우고 로그아웃 때 비운다.
/// 화면 어디서나 읽을 수 있게 core 에 두었다 — 세션 관리(features/auth)에
/// 두면 core 가 features 를 거꾸로 가져와야 한다.
///
/// 로그아웃 상태에서는 null 이다. 로그인 화면 말고는 null 일 일이 없지만,
/// 목업이 남아 있는 화면들이 아직 이름 문자열을 키로 쓰고 있어서
/// 읽는 쪽에서 기본값을 준다 (`me` 참고).
Employee? currentUser;
