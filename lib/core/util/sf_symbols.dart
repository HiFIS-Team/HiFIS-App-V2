import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

/// SF Symbol을 네이티브로 그릴 수 있는 플랫폼인지.
/// false면(안드로이드·윈도우) Flutter 아이콘으로 대체해야 한다.
bool get isApple =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// SF Symbol 이름 → 가장 닮은 Flutter 아이콘.
///
/// cupertino_native는 애플이 아닌 플랫폼에서 아이콘을 점 세 개/빈 원으로
/// 대체해버리므로, 심볼을 쓰는 위젯은 이 표를 거쳐 직접 그린다.
/// 데스크톱 사이드바와 같은 라운드 세트를 써서 플랫폼 간 모양을 맞춘다.
const _icons = <String, IconData>{
  // 헤더·화면 버튼
  'arrow.up.left.and.arrow.down.right': Icons.open_in_full_rounded,
  'barcode.viewfinder': Icons.qr_code_scanner_rounded,
  'bell': Icons.notifications_none_rounded,
  'building.2': Icons.apartment_rounded,
  // 지점이 걸려 있을 때 — 안 넣으면 안드로이드·윈도우에서 빈 원이 된다
  'building.2.fill': Icons.domain_rounded,
  'calendar': Icons.calendar_today_rounded,
  'calendar.badge.plus': Icons.edit_calendar_rounded,
  'checkmark': Icons.done_all_rounded,
  'checkmark.seal': Icons.approval_rounded,
  'chevron.backward': Icons.arrow_back_ios_new_rounded,
  'door.right.hand.open': Icons.logout_rounded,
  // 회의록을 프로젝트로 옮기기 — PC 쪽 버튼과 같은 아이콘이다
  'folder.badge.plus': Icons.create_new_folder_rounded,
  'line.3.horizontal.decrease': Icons.filter_list_rounded,
  // 필터가 걸려 있을 때 — 안 넣으면 안드로이드·윈도우에서 빈 원이 된다
  'line.3.horizontal.decrease.circle.fill': Icons.filter_alt_rounded,
  'message': Icons.chat_bubble_outline_rounded,
  'person': Icons.person_outline_rounded,
  // 사람 필터가 걸려 있을 때 (`PickFilterButton`) — 채운 아이콘으로 알린다
  'person.fill': Icons.person_rounded,
  // 회원 관리 — 데스크톱 사이드바의 '회원'과 같은 아이콘이다
  'person.2': Icons.people_alt_rounded,
  // 프로젝트 상세 헤더의 인원 추가 — 본문 `+` 동그라미와 같은 아이콘이다
  'person.badge.plus': Icons.person_add_alt_rounded,
  'plus': Icons.add_rounded,
  'square.and.pencil': Icons.edit_rounded,
  // 환경정비 항목 필터 (`PickFilterButton`) — 걸리면 채운다
  'tag': Icons.label_outline_rounded,
  'tag.fill': Icons.label_rounded,
  'trash': Icons.delete_outline_rounded,
  'xmark': Icons.close_rounded,
  // 하단 탭바
  'house.fill': Icons.home_rounded,
  'briefcase.fill': Icons.work_rounded,
  'folder.fill': Icons.folder_rounded,
  'doc.fill': Icons.insert_drive_file_rounded,
  // 운동일지 — 헤더 왼쪽에서 사람 아이콘 옆에 선다. **속을 안 채운 것**이라야
  // 옆 버튼들(외곽선)과 결이 맞는다 (`film` 과 같은 이유)
  'doc.text': Icons.description_outlined,
  'square.grid.2x2.fill': Icons.grid_view_rounded,
  'clock.fill': Icons.schedule_rounded,
  'wonsign.circle.fill': Icons.payments_rounded,
  'banknote.fill': Icons.payments_rounded,
  'megaphone.fill': Icons.campaign_rounded,
  'trophy.fill': Icons.emoji_events_rounded,
  // 추첨 게임 영상 — **트로피를 안 쓴다.** 그건 이미 랭킹이라
  // (사이드바·안드로이드 탭바·랭킹 알림) 같이 쓰면 헷갈린다.
  // 속을 안 채운 것을 골랐다 — 헤더 왼쪽에 서면 옆 버튼들이 다 외곽선이라
  // 채운 심볼은 **혼자 새까맣게 뜬다** (실제로 그렇게 보였다)
  'film': Icons.movie_outlined,
};

IconData iconForSymbol(String symbol) =>
    _icons[symbol] ?? Icons.circle_outlined;
