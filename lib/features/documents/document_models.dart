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
    _Kind.image => AppColors.violet,
    _Kind.video => AppColors.pink,
    _Kind.audio => AppColors.teal,
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
/// 서버는 폴더(`/folders`)와 문서(`/documents`)를 **평평하게** 준다.
/// 트리는 `parentId`·`folderId` 를 보고 [_buildTree] 가 세운다.
class _Item {
  _Item.folder({
    required this.name,
    required this.id,
    this.ownerId,
    this.updated,
    List<_Item>? children,
  }) : kind = _Kind.folder,
       bytes = 0,
       path = null,
       url = null,
       // 서버가 폴더에는 즐겨찾기를 안 준다
       starred = false,
       children = children ?? [];

  _Item.file({
    required this.name,
    required this.kind,
    required this.bytes,
    required this.id,
    this.ownerId,
    this.url,
    this.path,
    this.updated,
    this.starred = false,
  }) : children = null;

  /// 서버 uuid
  final String id;

  String name;
  final _Kind kind;

  /// 파일 크기 (폴더는 0)
  final int bytes;

  /// 만든 사람·올린 사람 — 본인이나 관리자만 고치고 지울 수 있다
  final String? ownerId;

  /// 마지막으로 손댄 시각 (서버 `updatedAt`)
  DateTime? updated;

  /// 즐겨찾기 — 서버에 **사람마다 따로** 남는다 (`favoritedByMe`).
  /// 폴더에는 없다 — 서버가 문서에만 준다
  bool starred;

  /// 서버에 올라간 파일 주소 (서명 포함). 폴더는 null
  final String? url;

  /// 방금 고른 파일의 로컬 경로 — 올린 직후 미리보기에 쓴다
  final String? path;

  /// null이면 파일
  final List<_Item>? children;

  bool get isFolder => children != null;

  /// 고치거나 지울 수 있는지 — 서버와 같은 기준이다
  bool get canEdit =>
      ownerId == null || ownerId == currentUser?.id || myRole.strong;

  /// 화면에 띄울 수 있는 이미지인지
  bool get canPreview => kind == _Kind.image && (path != null || url != null);

  /// 'KB · MB' 표기 — 파인더처럼 1000 단위로 끊는다
  String get sizeLabel {
    if (bytes >= 1000000) return '${(bytes / 1000000).toStringAsFixed(1)}MB';
    if (bytes >= 1000) return '${(bytes / 1000).round()}KB';
    return '${bytes}B';
  }

  /// 목록의 '수정한 날짜' 칸 — 오늘이면 시각만 보여준다 (파인더와 같게)
  String get updatedLabel {
    final at = updated;
    if (at == null) return '--';
    final now = DateTime.now();
    final time =
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return '오늘 $time';
    }
    return '${at.year % 100}. ${at.month}. ${at.day}. $time';
  }
}

/// 최상위 폴더 — 탭을 오가도 유지되도록 모듈 전역으로 둔다.
/// 이름은 갈래를 따라간다 (`전사 문서` ↔ `내 문서`) — 경로 줄 첫 칸에 뜬다
final _root = _Item.folder(name: DocScope.company.label, id: '', children: []);

/// 지금 보고 있는 갈래. 바꾸면 트리를 통째로 다시 받는다
DocScope _scope = DocScope.company;

/// 지금 [_root] 에 담겨 있는 갈래 — null 이면 아직 아무것도 안 받았다.
/// 트리는 하나뿐이라 갈래를 바꾸면 통째로 갈아끼운다
DocScope? _treeScope;

/// 서버에서 받아 트리를 다시 세운다
///
/// 폴더·문서를 한 번에 받아서 `parentId`·`folderId` 로 이어 붙인다.
/// 폴더마다 문서를 따로 받으면 폴더 수만큼 요청이 나간다.
Future<void> _loadTree() async {
  if (_treeScope == _scope) return;
  final folders = DocumentApi.folders(_scope);
  final documents = DocumentApi.documents(_scope);
  _buildTree(await folders, await documents);
  _treeScope = _scope;
}

void _buildTree(List<Folder> folders, List<Document> documents) {
  _root.name = _scope.label;
  final nodes = <String, _Item>{
    for (final folder in folders)
      folder.id: _Item.folder(
        name: folder.name,
        id: folder.id,
        ownerId: folder.createdById,
        updated: folder.updatedAt ?? folder.createdAt,
      ),
  };

  _root.children!.clear();

  // 폴더를 부모 밑에 건다 — 부모가 사라진 폴더는 최상위로 올린다
  for (final folder in folders) {
    final node = nodes[folder.id]!;
    (nodes[folder.parentId]?.children ?? _root.children!).add(node);
  }

  for (final document in documents) {
    final node = _itemOf(document);
    (nodes[document.folderId]?.children ?? _root.children!).add(node);
  }
}

/// 서버 문서 하나를 화면 항목으로. [path] 는 방금 고른 파일의 로컬 경로다
_Item _itemOf(Document document, {String? path}) => _Item.file(
  name: document.name,
  kind: _Kind.of('x.${document.ext}'),
  bytes: document.sizeBytes,
  id: document.id,
  ownerId: document.uploaderId,
  url: document.fileUrl,
  updated: document.updatedAt ?? document.createdAt,
  starred: document.favoritedByMe,
  path: path,
);

/// uuid → 올린 사람 이름
String _uploaderName(String id) =>
    StaffDirectory.instance.byId(id)?.name ?? '알 수 없음';

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

/// 올리는·받는 중임을 알리는 작은 알약 (우하단)
class _UploadingChip extends StatelessWidget {
  _UploadingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.gray100),
        boxShadow: [
          BoxShadow(
            color: AppShadows.ink.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          SizedBox(width: 10),
          Text(
            label,
            style: AppTextStyles.body2.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
