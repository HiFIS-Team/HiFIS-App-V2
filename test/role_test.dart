import 'package:flutter_test/flutter_test.dart';
import 'package:hifis_app/core/data/employee.dart';

/// 권한 판정을 **표 하나로 못 박아 둔다.**
///
/// 예전에는 `master || admin` 같은 식이 화면마다 따로 적혀 있었다 —
/// 이름도 `_isBoss` · `_isRankBoss` · `_isPayBoss` · `_givenOnly` ·
/// `_canSeeOthers` 로 갈려서, 규칙이 바뀔 때 한 곳만 빠뜨리면 **그 화면만
/// 조용히 틀렸다.** 지금은 [Role] 의 getter 다섯이 그 자리를 다 맡는다.
///
/// 여기가 깨지면 **고치기 전에 의도한 변경인지 먼저 확인한다.** 값 하나를
/// 바꾸면 홈·근태·급여·랭킹·기여도·일정·프로젝트가 같이 움직인다.
void main() {
  /// 각 getter 가 참이어야 하는 권한들 — 나머지는 전부 거짓이어야 한다
  const table = <String, Set<Role>>{
    'strong': {Role.master, Role.admin, Role.manager},
    'boss': {Role.master, Role.admin},
    'canApprove': {Role.master},
    'canGrant': {Role.master, Role.admin, Role.manager},
    'doesFieldWork': {Role.manager, Role.member},
  };

  bool call(String name, Role r) => switch (name) {
    'strong' => r.strong,
    'boss' => r.boss,
    'canApprove' => r.canApprove,
    'canGrant' => r.canGrant,
    'doesFieldWork' => r.doesFieldWork,
    _ => throw ArgumentError(name),
  };

  for (final entry in table.entries) {
    test('${entry.key} 는 ${entry.value.map((r) => r.wire).join("·")} 만', () {
      for (final role in Role.values) {
        expect(
          call(entry.key, role),
          entry.value.contains(role),
          reason: '${role.wire} 에서 ${entry.key} 가 어긋난다',
        );
      }
    });
  }

  test('boss 와 strong 은 MANAGER 에서 갈린다', () {
    // 둘을 헷갈려 바꿔 쓰면 점장 화면이 통째로 달라진다.
    // boss = 본인 기록이 없는 사람, strong = 관리 작업을 할 수 있는 사람.
    expect(Role.manager.strong, isTrue);
    expect(Role.manager.boss, isFalse);
  });

  test('선언 순서가 곧 정렬 순서다 (높은 권한부터)', () {
    expect(Role.values, [Role.master, Role.admin, Role.manager, Role.member]);
  });

  test('서버 값과 왕복한다', () {
    for (final role in Role.values) {
      expect(Role.parse(role.wire), role);
    }
    // 모르는 값·null 은 제일 낮은 권한으로 떨어진다 (권한 상승이 안 나게)
    expect(Role.parse('SUPERUSER'), Role.member);
    expect(Role.parse(null), Role.member);
  });
}
