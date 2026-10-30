import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// **애플 화면**(네이티브 글래스 버튼·탭바·메뉴·SF Symbol)을 쓸 기기인지.
/// false면 안드로이드와 같은 화면이다 — Flutter 아이콘·Flutter 블러로 그린다.
///
/// **iOS 는 26 부터다** (2026-10-27 대표 요청). iOS 18~25 에는 리퀴드 글래스가
/// 없어서 네이티브 부품이 예전 납작한 모양으로 떴다 — 그래서 안드로이드와
/// **똑같은 화면**으로 보낸다. 화면 분기 스무 곳 남짓이 이 값 하나를 보므로
/// 여기서 가르면 탭바·버튼·메뉴·여백 계산이 한꺼번에 따라간다.
///
/// 맥은 그대로 애플 화면이다 (데스크톱 셸이 따로 있다).
///
/// ⚠️ **화면 모양이 아닌 것**(애플 컬러 이모지 글꼴, 창 외관 맞추기)은
/// [isApplePlatform] 을 본다 — 그건 iOS 버전과 상관없다.
bool get isApple => isApplePlatform && _liquidGlass;

/// OS 가 애플인가 — 버전을 안 따진다 ([isApple] 과 다르다)
bool get isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// iOS 가 리퀴드 글래스를 그리는가 — [detectLiquidGlass] 가 채운다
///
/// **기본은 true** 다. 못 물어보면(채널이 없는 빌드·웹) 예전 그대로 애플
/// 화면에 둔다 — 잘못 내려서 iOS 26 사용자가 안드로이드 화면을 보는 것보다 낫다.
bool _liquidGlass = true;

/// 앱을 켤 때 **`runApp` 전에** 한 번 부른다 — 화면이 서는 도중에 값이
/// 바뀌면 탭바가 통째로 갈아끼워진다
///
/// 판정은 네이티브가 한다 (`AppDelegate` 의 `com.hifis/os`) — 유리 면이
/// 고르는 `#available(iOS 26.0, *)` 와 같은 검사라 둘이 어긋나지 않는다.
Future<void> detectLiquidGlass() async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    _liquidGlass =
        await const MethodChannel(
          'com.hifis/os',
        ).invokeMethod<bool>('liquidGlass') ??
        true;
  } catch (_) {
    // 채널이 없다 — 예전처럼 애플 화면에 둔다
  }
}

/// SF Symbol 이름 → 가장 닮은 Flutter 아이콘.
///
/// cupertino_native는 애플이 아닌 플랫폼에서 아이콘을 점 세 개/빈 원으로
/// 대체해버리므로, 심볼을 쓰는 위젯은 이 표를 거쳐 직접 그린다.
/// 데스크톱 사이드바와 같은 라운드 세트를 써서 플랫폼 간 모양을 맞춘다.
const _icons = <String, IconData>{
  // 헤더·화면 버튼
  'arrow.up.left.and.arrow.down.right': Icons.open_in_full_rounded,
  // 다시 받기 — PT 만족도처럼 **밖에서 값이 들어오는** 화면이 쓴다.
  // 회원이 방금 낸 답을 보려면 화면을 닫았다 여는 수밖에 없었다
  'arrow.clockwise': Icons.refresh_rounded,
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
  // 지점 통계 — 환경정비 헤더의 그래프 버튼
  'chart.bar': Icons.bar_chart_rounded,
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
  // 운동일지 펜 모드 고르개 — 켜짐·꺼짐이 둘 다 필요하다 (`pen_mode.dart`)
  'pencil.tip': Icons.edit_outlined,
  'keyboard': Icons.keyboard_outlined,
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
  // 완료된 프로젝트를 처음으로 되돌리는 자리 (MASTER 전용).
  // 새로고침이 아니라 **되감기**라 시계 반대 방향을 쓴다
  'arrow.counterclockwise': Icons.refresh,
  // 매장 TV 를 앱에서 보는 자리 — 추첨 영상과 한 메뉴에 선다.
  // `film` 과 같은 이유로 속을 안 채운다
  'tv': Icons.tv_outlined,
  // PT 만족도 폼 — 수업 개수 헤더에서 사람·일지 옆에 선다.
  // 옆 줄이 다 외곽선이라 여기도 속을 안 채운다 (`film`·`doc.text` 와 같은 이유)
  'star.bubble': Icons.reviews_outlined,
};

IconData iconForSymbol(String symbol) =>
    _icons[symbol] ?? Icons.circle_outlined;
