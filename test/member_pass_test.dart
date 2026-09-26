import 'package:flutter_test/flutter_test.dart';
import 'package:hifis_app/core/api/work/lesson_api.dart';

Registration _reg(
  String id, {
  required int total,
  required int used,
  required DateTime at,
  RegistrationType type = RegistrationType.renewal,
}) => Registration(
  id: id,
  memberId: 'm',
  trainerId: 't',
  type: type,
  totalSessions: total,
  usedSessions: used,
  pricePaid: 0,
  sessionUnitPrice: 0,
  status: used >= total
      ? RegistrationStatus.expired
      : RegistrationStatus.active,
  purchasedAt: at,
);

void main() {
  final old = _reg(
    'old',
    total: 20,
    used: 12,
    at: DateTime(2026, 8, 1),
    type: RegistrationType.newMember,
  );
  final renew = _reg('new', total: 10, used: 0, at: DateTime(2026, 9, 20));

  test('미리 재등록하면 남은 회차가 합쳐진다 — 8 + 10 = 18', () {
    final pass = MemberPass.of([renew, old], 'm');
    expect(pass.remaining, 18);
    expect('${pass.used}/${pass.total}', '12/30');
    // 차감은 먼저 산 것부터, 표시는 최근 등록(재등록) 기준
    expect(pass.current?.id, 'old');
    expect(pass.latest?.id, 'new');
    expect(pass.latest?.type, RegistrationType.renewal);
  });

  test('다 쓴 등록권은 합치지 않는다', () {
    final spent = _reg('spent', total: 10, used: 10, at: DateTime(2026, 7, 1));
    final pass = MemberPass.of([spent, renew], 'm');
    expect('${pass.used}/${pass.total}', '0/10');
    expect(pass.current?.id, 'new');
  });

  test('전부 다 썼으면 마지막 것을 그대로 — 재등록 필요', () {
    final spent = _reg('spent', total: 20, used: 20, at: DateTime(2026, 7, 1));
    final pass = MemberPass.of([spent], 'm');
    expect('${pass.used}/${pass.total}', '20/20');
    expect(pass.active, isFalse);
    expect(pass.exists, isTrue);
  });

  test('등록권이 없으면 없다', () {
    final pass = MemberPass.of([old], 'other');
    expect(pass.exists, isFalse);
    expect(pass.active, isFalse);
  });
}
