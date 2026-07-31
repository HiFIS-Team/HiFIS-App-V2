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
  'calendar.badge.plus': Icons.edit_calendar_rounded,
  'checkmark': Icons.done_all_rounded,
  'chevron.backward': Icons.arrow_back_ios_new_rounded,
  'door.right.hand.open': Icons.logout_rounded,
  'line.3.horizontal.decrease': Icons.filter_list_rounded,
  'message': Icons.chat_bubble_outline_rounded,
  'person': Icons.person_outline_rounded,
  'plus': Icons.add_rounded,
  'square.and.pencil': Icons.edit_rounded,
  'trash': Icons.delete_outline_rounded,
  'xmark': Icons.close_rounded,
  // 하단 탭바
  'house.fill': Icons.home_rounded,
  'briefcase.fill': Icons.work_rounded,
  'folder.fill': Icons.folder_rounded,
  'doc.fill': Icons.insert_drive_file_rounded,
  'square.grid.2x2.fill': Icons.grid_view_rounded,
  'clock.fill': Icons.schedule_rounded,
  'wonsign.circle.fill': Icons.payments_rounded,
  'banknote.fill': Icons.payments_rounded,
  'megaphone.fill': Icons.campaign_rounded,
  'trophy.fill': Icons.emoji_events_rounded,
};

IconData iconForSymbol(String symbol) =>
    _icons[symbol] ?? Icons.circle_outlined;
