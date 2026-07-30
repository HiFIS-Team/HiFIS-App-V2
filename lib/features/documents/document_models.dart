part of 'document_screen.dart';

/// 좌측 사이드바의 위치 — 폴더 구조와 별개로 문서를 모아 본다
enum _Place {
  all('전체 문서', Icons.folder_rounded),
  recent('최근 항목', Icons.schedule_rounded),
  starred('즐겨찾기', Icons.star_rounded);

  const _Place(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 문서 종류 — 아이콘과 색을 여기서 정한다
enum _Kind {
  folder('폴더', Icons.folder_rounded),
  pdf('PDF', Icons.picture_as_pdf_rounded),
  doc('문서', Icons.description_rounded),
  sheet('스프레드시트', Icons.table_chart_rounded),
  slide('프레젠테이션', Icons.slideshow_rounded),
  image('이미지', Icons.image_rounded),
  video('동영상', Icons.movie_rounded),
  audio('오디오', Icons.audiotrack_rounded),
  archive('압축 파일', Icons.folder_zip_rounded),
  other('파일', Icons.insert_drive_file_rounded);

  const _Kind(this.label, this.icon);

  final String label;
  final IconData icon;

  /// 파인더처럼 종류마다 색을 달리 해서 훑어볼 때 바로 구분되게 한다
  Color get color => switch (this) {
    _Kind.folder => Color(0xFF5AA9FF),
    _Kind.pdf => AppColors.error,
    _Kind.doc => AppColors.primary,
    _Kind.sheet => AppColors.success,
    _Kind.slide => AppColors.warning,
    _Kind.image => Color(0xFF7C5CFC),
    _Kind.video => Color(0xFFE0447C),
    _Kind.audio => Color(0xFF00A8B5),
    _Kind.archive => AppColors.gray500,
    _Kind.other => AppColors.gray500,
  };

  /// 확장자로 종류를 고른다 (올린 파일의 아이콘·색을 정하는 데 쓴다)
  static _Kind of(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'pdf' => _Kind.pdf,
      'doc' || 'docx' || 'txt' || 'rtf' || 'hwp' || 'md' => _Kind.doc,
      'xls' || 'xlsx' || 'csv' || 'numbers' => _Kind.sheet,
      'ppt' || 'pptx' || 'key' => _Kind.slide,
      'png' ||
      'jpg' ||
      'jpeg' ||
      'gif' ||
      'webp' ||
      'heic' ||
      'bmp' => _Kind.image,
      'mp4' || 'mov' || 'avi' || 'mkv' || 'webm' || 'm4v' => _Kind.video,
      'mp3' || 'wav' || 'm4a' || 'aac' || 'flac' => _Kind.audio,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => _Kind.archive,
      _ => _Kind.other,
    };
  }
}

/// 문서함 항목 — 폴더이거나 파일이다
///
/// 폴더는 [children]을 가지고, 파일은 null이다.
class _Item {
  _Item.folder({required this.name, List<_Item>? children, DateTime? updated})
    : kind = _Kind.folder,
      bytes = 0,
      path = null,
      children = children ?? [],
      updated = updated ?? DateTime.now();

  _Item.file({
    required this.name,
    required this.kind,
    required this.bytes,
    required this.updated,
    this.starred = false,
    this.path,
  }) : children = null;

  String name;
  final _Kind kind;

  /// 파일 크기 (폴더는 0)
  final int bytes;

  DateTime updated;
  bool starred = false;

  /// 올린 파일의 실제 경로 — 목업 데이터는 null이라 미리보기가 없다
  final String? path;

  /// null이면 파일
  final List<_Item>? children;

  bool get isFolder => children != null;

  /// 실제로 올린 이미지라 화면에 띄울 수 있는지
  bool get canPreview => path != null && kind == _Kind.image;

  /// 'KB · MB' 표기 — 파인더처럼 1000 단위로 끊는다
  String get sizeLabel {
    if (bytes >= 1000000) return '${(bytes / 1000000).toStringAsFixed(1)}MB';
    if (bytes >= 1000) return '${(bytes / 1000).round()}KB';
    return '${bytes}B';
  }
}

/// 최상위 폴더 — 탭을 오가도 유지되도록 모듈 전역으로 둔다
final _root = _Item.folder(name: '문서함', children: _seedTree());

/// 트리 전체를 한 줄로 펴서 돌려준다 (최근 항목·즐겨찾기에 쓴다)
List<_Item> _collect(_Item folder) {
  final all = <_Item>[];
  for (final child in folder.children!) {
    all.add(child);
    if (child.isFolder) all.addAll(_collect(child));
  }
  return all;
}

/// [target]을 담고 있는 폴더를 찾는다 (삭제할 때 필요)
_Item? _parentOf(_Item folder, _Item target) {
  if (folder.children!.contains(target)) return folder;
  for (final child in folder.children!.where((i) => i.isFolder)) {
    final found = _parentOf(child, target);
    if (found != null) return found;
  }
  return null;
}

/// '7.28 오후 3:20' 형태
String _stamp(DateTime time) {
  final period = time.hour < 12 ? '오전' : '오후';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.month}.${time.day} $period $hour:$minute';
}

List<_Item> _seedTree() {
  final now = DateTime.now();
  DateTime at(int daysAgo, int hour, int minute) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour, minute);

  return [
    _Item.folder(
      name: '계약서',
      updated: at(2, 14, 10),
      children: [
        _Item.file(
          name: '회원 이용 계약서 양식.pdf',
          kind: _Kind.pdf,
          bytes: 284000,
          updated: at(2, 14, 10),
          starred: true,
        ),
        _Item.file(
          name: '트레이너 근로계약서.pdf',
          kind: _Kind.pdf,
          bytes: 196000,
          updated: at(9, 11, 32),
        ),
        _Item.file(
          name: '센터 임대차 계약서.pdf',
          kind: _Kind.pdf,
          bytes: 1420000,
          updated: at(41, 16, 5),
        ),
        _Item.folder(
          name: '만료 예정',
          updated: at(6, 9, 15),
          children: [
            _Item.file(
              name: '정수기 렌탈 계약.pdf',
              kind: _Kind.pdf,
              bytes: 132000,
              updated: at(6, 9, 15),
            ),
          ],
        ),
      ],
    ),
    _Item.folder(
      name: '인사',
      updated: at(1, 10, 40),
      children: [
        _Item.file(
          name: '취업규칙.pdf',
          kind: _Kind.pdf,
          bytes: 512000,
          updated: at(24, 13, 20),
        ),
        _Item.file(
          name: '급여 규정.docx',
          kind: _Kind.doc,
          bytes: 88000,
          updated: at(12, 15, 48),
        ),
        _Item.file(
          name: '신입 온보딩 체크리스트.xlsx',
          kind: _Kind.sheet,
          bytes: 46000,
          updated: at(1, 10, 40),
          starred: true,
        ),
      ],
    ),
    _Item.folder(
      name: '매출',
      updated: at(0, 17, 22),
      children: [
        _Item.file(
          name: '2026 상반기 매출.xlsx',
          kind: _Kind.sheet,
          bytes: 342000,
          updated: at(3, 18, 2),
        ),
        _Item.file(
          name: '7월 정산.xlsx',
          kind: _Kind.sheet,
          bytes: 128000,
          updated: at(0, 17, 22),
        ),
        _Item.file(
          name: '회원권 단가표.xlsx',
          kind: _Kind.sheet,
          bytes: 64000,
          updated: at(18, 9, 55),
        ),
      ],
    ),
    _Item.folder(
      name: '마케팅',
      updated: at(0, 11, 5),
      children: [
        _Item.file(
          name: '여름 프로모션 포스터.png',
          kind: _Kind.image,
          bytes: 4820000,
          updated: at(0, 11, 5),
          starred: true,
        ),
        _Item.file(
          name: 'SNS 콘텐츠 캘린더.xlsx',
          kind: _Kind.sheet,
          bytes: 72000,
          updated: at(4, 14, 30),
        ),
        _Item.file(
          name: '전단지 시안.zip',
          kind: _Kind.archive,
          bytes: 12400000,
          updated: at(7, 16, 44),
        ),
      ],
    ),
    _Item.folder(
      name: '센터 운영',
      updated: at(0, 8, 50),
      children: [
        _Item.file(
          name: '기구 점검표.xlsx',
          kind: _Kind.sheet,
          bytes: 38000,
          updated: at(0, 8, 50),
        ),
        _Item.file(
          name: '청소 체크리스트.pdf',
          kind: _Kind.pdf,
          bytes: 96000,
          updated: at(5, 19, 12),
        ),
        _Item.file(
          name: '비상 연락망.docx',
          kind: _Kind.doc,
          bytes: 42000,
          updated: at(15, 10, 8),
        ),
      ],
    ),
    _Item.folder(
      name: '회의 자료',
      updated: at(1, 15, 0),
      children: [
        _Item.file(
          name: '2026 사업계획.pptx',
          kind: _Kind.slide,
          bytes: 8600000,
          updated: at(28, 17, 40),
        ),
        _Item.file(
          name: '월간 회의 자료.pptx',
          kind: _Kind.slide,
          bytes: 3200000,
          updated: at(1, 15, 0),
        ),
      ],
    ),
    _Item.file(
      name: '사업자등록증.pdf',
      kind: _Kind.pdf,
      bytes: 220000,
      updated: at(60, 9, 0),
      starred: true,
    ),
    _Item.file(
      name: '로고 원본.zip',
      kind: _Kind.archive,
      bytes: 24800000,
      updated: at(33, 13, 25),
    ),
  ];
}
