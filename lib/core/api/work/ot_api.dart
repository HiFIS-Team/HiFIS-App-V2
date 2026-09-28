import 'package:flutter/material.dart' show TimeOfDay;

import '../client/api_client.dart';
import '../client/period.dart' show dateKey;

/// OT 신청 단계 — 서버 `OtStatus`
enum OtStatus {
  pending('PENDING', '미배정'),
  assigned('ASSIGNED', '수락 대기'),
  accepted('ACCEPTED', '확정');

  const OtStatus(this.wire, this.label);

  final String wire;
  final String label;

  static OtStatus parse(String? value) => OtStatus.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => OtStatus.pending,
  );
}

/// OT 신청 한 건 (서버 `OtRequestOut`) — 네이버 플레이스·전단지 QR 로 들어온다
class OtRequest {
  OtRequest({
    required this.id,
    required this.branchId,
    required this.name,
    required this.male,
    required this.age,
    required this.phone,
    required this.purpose,
    required this.visitDate,
    required this.start,
    required this.end,
    required this.status,
    required this.createdAt,
    this.branchName,
    this.assigneeId,
    this.assigneeName,
    this.assignedById,
    this.convertedAt,
  });

  factory OtRequest.fromJson(Map<String, dynamic> json) => OtRequest(
    id: json['id'] as String,
    branchId: json['branchId'] as String,
    branchName: json['branchName'] as String?,
    name: json['name'] as String,
    male: json['gender'] == 'MALE',
    age: json['age'] as int,
    phone: json['phone'] as String,
    purpose: json['purpose'] as String,
    visitDate: DateTime.parse(json['visitDate'] as String),
    start: _time(json['startTime'] as String),
    end: _time(json['endTime'] as String),
    status: OtStatus.parse(json['status'] as String?),
    assigneeId: json['assigneeId'] as String?,
    assigneeName: json['assigneeName'] as String?,
    assignedById: json['assignedById'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    convertedAt: json['convertedAt'] == null
        ? null
        : DateTime.parse(json['convertedAt'] as String).toLocal(),
  );

  final String id;
  final String branchId;
  final String? branchName;
  final String name;
  final bool male;
  final int age;

  /// 숫자만 (`01012345678`)
  final String phone;
  final String purpose;
  final DateTime visitDate;
  final TimeOfDay start;
  final TimeOfDay end;
  final OtStatus status;
  final String? assigneeId;
  final String? assigneeName;
  final String? assignedById;
  final DateTime createdAt;

  /// 이름·연락처가 같은 신규 등록이 들어왔다 — PT 로 전환됐다
  final DateTime? convertedAt;

  /// `10/2(목) 14:00~15:00`
  String get when {
    const days = '월화수목금토일';
    final d = visitDate;
    return '${d.month}/${d.day}(${days[d.weekday - 1]}) '
        '${hhmm(start)}~${hhmm(end)}';
  }

  /// `010-1234-5678`
  String get phoneLabel => phone.length == 11
      ? '${phone.substring(0, 3)}-${phone.substring(3, 7)}-${phone.substring(7)}'
      : phone;
}

TimeOfDay _time(String value) {
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// OT 신청 관리 (2026-09-28 대표 요청) — 신청은 손님이 `hifis.app/ot/{지점}` 에서 낸다
class OtApi {
  OtApi._();

  /// 볼 수 있는 OT 전부 — 서버가 권한대로 거른다
  /// (MEMBER 는 자기 것만, FC 는 자기 지점 미배정도)
  static Future<List<OtRequest>> list() async {
    final rows = await ApiClient.instance.getList('/ot-requests');
    return [
      for (final row in rows)
        OtRequest.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  static Future<OtRequest> assign(String id, String assigneeId) async =>
      OtRequest.fromJson(
        (await ApiClient.instance.post(
          '/ot-requests/$id/assign',
          body: {'assigneeId': assigneeId},
        ))!,
      );

  /// 수락 — 시간이 안 맞으면 고쳐서 낸다. 공통 일정이 서고 신청자에게 문자가 간다
  static Future<OtRequest> accept(
    String id, {
    required DateTime date,
    required TimeOfDay start,
    required TimeOfDay end,
  }) async => OtRequest.fromJson(
    (await ApiClient.instance.post(
      '/ot-requests/$id/accept',
      body: {
        'visitDate': dateKey(date),
        'startTime': hhmm(start),
        'endTime': hhmm(end),
      },
    ))!,
  );

  /// 거절 — 다시 미배정으로 돌아간다
  static Future<OtRequest> reject(String id) async => OtRequest.fromJson(
    (await ApiClient.instance.post('/ot-requests/$id/reject'))!,
  );
}
