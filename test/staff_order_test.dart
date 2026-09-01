/// 사람을 세우는 **공통 차례** — 지점 → 직급 → 이름
///
/// 화면마다 이름순으로 세우면 같은 사람이 화면마다 다른 자리에 있어서 눈이
/// 자리를 못 외운다. 그래서 한 곳([StaffDirectory.compareStaff])에서만 정하고
/// 조직도·동료평가·환경정비 사람 필터·수업 트레이너·일정 참석자·사내톡
/// 멤버·홈 출근이 다 그걸 쓴다 (2026-09-01 대표 요청).
///
/// 깨지면 고치기 전에 의도한 변경인지 먼저 확인한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hifis_app/core/api/staff/staff_api.dart';
import 'package:hifis_app/core/data/employee.dart';
import 'package:hifis_app/core/data/staff_directory.dart';

const _hq = 'b-hq';
const _hwasun = 'b-hwasun';
const _cheomdan = 'b-cheomdan';
const _dgj = 'b-dgj';

Employee _p(
  String name,
  String branchId,
  Rank rank, {
  Role role = Role.member,
}) => Employee(
  id: 'e-$name',
  name: name,
  email: '$name@hifis.local',
  branchId: branchId,
  rank: rank,
  role: role,
  avatarColor: '#2F54EB',
);

void _seed(List<Employee> people) {
  StaffDirectory.instance
    ..branches = [
      Branch(id: _hq, name: '전 지점', type: 'HQ'),
      // 서버가 주는 차례를 일부러 흩어 둔다 — 이름으로 세워야 한다
      Branch(id: _dgj, name: '동광주', type: 'BRANCH'),
      Branch(id: _cheomdan, name: '첨단', type: 'BRANCH'),
      Branch(id: _hwasun, name: '화순', type: 'BRANCH'),
    ]
    ..employees = people;
}

List<String> _sorted(List<Employee> people) {
  _seed(people);
  final rows = [...people]..sort(StaffDirectory.instance.compareStaff);
  return [for (final e in rows) e.name];
}

void main() {
  tearDown(StaffDirectory.instance.clear);

  test('1순위는 지점 — 화순 · 첨단 · 동광주', () {
    expect(
      _sorted([
        _p('동광주사람', _dgj, Rank.trainer),
        _p('첨단사람', _cheomdan, Rank.trainer),
        _p('화순사람', _hwasun, Rank.trainer),
      ]),
      ['화순사람', '첨단사람', '동광주사람'],
    );
  });

  test('직급이 높아도 지점이 먼저다', () {
    expect(
      _sorted([
        _p('첨단점장', _cheomdan, Rank.storeManager),
        _p('화순FC', _hwasun, Rank.fc),
      ]),
      ['화순FC', '첨단점장'],
    );
  });

  test('2순위는 직급 — 점장 · 팀장 · 트레이너 · FC', () {
    expect(
      _sorted([
        _p('에프씨', _hwasun, Rank.fc),
        _p('트레이너', _hwasun, Rank.trainer),
        _p('팀장', _hwasun, Rank.teamLead),
        _p('점장', _hwasun, Rank.storeManager),
      ]),
      ['점장', '팀장', '트레이너', '에프씨'],
    );
  });

  test('3순위는 이름', () {
    expect(
      _sorted([
        _p('나트레이너', _hwasun, Rank.trainer),
        _p('가트레이너', _hwasun, Rank.trainer),
      ]),
      ['가트레이너', '나트레이너'],
    );
  });

  test('HQ(전 지점) 소속인 MASTER·ADMIN 은 맨 앞이다', () {
    expect(
      _sorted([
        _p('화순점장', _hwasun, Rank.storeManager, role: Role.manager),
        _p('대표', _hq, Rank.ceo, role: Role.master),
      ]),
      ['대표', '화순점장'],
    );
  });

  test('모르는 지점은 뒤로 민다', () {
    expect(
      _sorted([
        _p('떠돌이', 'b-없음', Rank.storeManager),
        _p('동광주트레이너', _dgj, Rank.trainer),
      ]),
      ['동광주트레이너', '떠돌이'],
    );
  });

  test('직급 차례는 Rank 선언 순서 그대로다', () {
    // 표를 새로 만들면 둘이 갈린다 — 선언 순서가 곧 화면 순서다
    expect(Rank.values.map((r) => r.label).toList(), [
      '대표',
      '개발자',
      '마케터',
      '점장',
      '팀장',
      '트레이너',
      'FC',
    ]);
  });

  group('고르개 — id·이름만 든 목록', () {
    test('명단에서 찾아 같은 차례로 세운다', () {
      _seed([
        _p('첨단트레이너', _cheomdan, Rank.trainer),
        _p('화순점장', _hwasun, Rank.storeManager),
      ]);
      final d = StaffDirectory.instance;
      final rows = [
        (id: 'e-첨단트레이너', name: '첨단트레이너'),
        (id: 'e-화순점장', name: '화순점장'),
      ]..sort((a, b) => d.compareStaffIds(a.id, b.id, a.name, b.name));
      expect(rows.map((r) => r.name), ['화순점장', '첨단트레이너']);
    });

    test('명단에 없는 사람은 뒤로 밀고 이름순', () {
      _seed([_p('화순트레이너', _hwasun, Rank.trainer)]);
      final d = StaffDirectory.instance;
      final rows = [
        (id: 'e-없음2', name: '나없는사람'),
        (id: 'e-없음1', name: '가없는사람'),
        (id: 'e-화순트레이너', name: '화순트레이너'),
      ]..sort((a, b) => d.compareStaffIds(a.id, b.id, a.name, b.name));
      expect(rows.map((r) => r.name), ['화순트레이너', '가없는사람', '나없는사람']);
    });
  });
}
