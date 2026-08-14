/// 지금 보고 있는 지점 — PC 헤더 아이콘 하나가 정하고 여러 화면이 같이 본다
///
/// 예전에는 조직도·업무·랭킹이 **각자 지점 고르개를 하나씩** 들고 있었다.
/// 화순을 보다가 옆 화면으로 옮기면 다시 전체로 돌아가서, 한 지점을 훑어보려면
/// 화면마다 다시 골라야 했다. 고르개를 헤더로 한 번만 두고 값을 여기 모은다.
///
/// **id 로 들고 이름은 필요할 때 만든다.** 지점 이름은 바뀔 수 있고 서버가
/// 주고받는 것도 id 라, 이름을 키로 쓰면 이름을 고치는 순간 필터가 끊긴다.
library;

import 'package:flutter/foundation.dart';

import 'employee.dart';
import 'staff.dart';
import 'staff_directory.dart';

/// 지점 필터에서 '전 지점'을 가리키는 이름
///
/// 조직도·랭킹이 이름으로 걸러서 그 화면들이 쓰는 값과 같아야 한다.
///
/// **서버의 HQ 지점 이름과 같은 값이다** (둘 다 `전 지점`). HQ 는 필터에서
/// 빼기 때문에 한 줄에 두 개가 서지는 않는다.
const allBranchesLabel = '전 지점';

/// 고른 지점 id — **null 이면 전 지점**
///
/// 직접 읽지 말고 [branchScopeId] 를 쓴다. 볼 권한이 없는 사람에게까지
/// 이 값이 걸리면 안 된다.
final branchScope = ValueNotifier<String?>(null);

/// 이 사람에게 지점 고르개를 보여줄 것인가 — **MEMBER 만 빼고**
///
/// MEMBER 는 서버(`branch_filter`)가 본인 지점으로 고정해서 골라 봐야 바뀌는
/// 것이 없다. 버튼을 세워 두면 눌러도 아무 일이 없는 자리가 된다.
///
/// **MANAGER 는 고르는 범위가 좁다 (2026-08-14).** 점장에게 지점을 준 이유가
/// '다른 지점이 어떻게 하나 보라'는 것이라, 서버가 **업무 화면만** 열어 준다
/// (`branch_pick` — 환경정비·회원·등록권·세션싸인·친절도·기여도).
/// 랭킹·조직도는 원래 서버 스코프를 안 타고 앱이 지점 이름으로 거르므로
/// 같이 따라온다.
///
/// **여는 것은 보는 것뿐이다.** 결재는 MASTER 전용이고 남의 근태·급여는
/// MASTER·ADMIN 만 보는데, 그건 각자의 권한 가드가 막아서 지점을 골라도
/// 안 열린다. 예전에 이 둘을 한 스위치로 묶었다가 점장이 남의 월차를
/// 결재하게 된 적이 있다.
///
/// 그래서 **안 고른 상태(`전 지점`)에서는 오늘과 화면이 똑같다** — 업무는
/// 서버가 본인 지점으로, 랭킹·조직도는 전사로. 고를 때만 달라진다.
bool get branchScopeVisible => myRole != Role.member;

/// 화면이 실제로 걸어야 할 지점 id — 볼 권한이 없으면 늘 null
///
/// 대표로 화순을 보다가 로그아웃하고 다른 사람이 들어와도 그 값이 남아
/// 따라붙지 않는다.
String? get branchScopeId => branchScopeVisible ? branchScope.value : null;

/// 고른 지점 이름 — 안 골랐거나 볼 권한이 없으면 [allBranchesLabel]
///
/// 조직도·랭킹은 사람의 **지점 이름**으로 거르기 때문에 이 값을 쓴다.
String get branchScopeName {
  final id = branchScopeId;
  if (id == null) return allBranchesLabel;
  final name = StaffDirectory.instance.branchName(id);
  return name.isEmpty ? allBranchesLabel : name;
}

/// 로그아웃할 때 되돌린다 — 다음 사람에게 앞사람이 보던 지점이 남지 않게
void resetBranchScope() => branchScope.value = null;
