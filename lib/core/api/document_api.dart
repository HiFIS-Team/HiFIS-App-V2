import 'package:dio/dio.dart';

import 'api_client.dart';

/// 문서함 폴더 (서버 `FolderOut`)
class Folder {
  Folder({
    required this.id,
    required this.name,
    required this.scope,
    required this.space,
    required this.createdById,
    this.parentId,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
    id: json['id'] as String,
    name: json['name'] as String,
    scope: json['scope'] as String? ?? '',
    space: json['space'] as String? ?? '',
    parentId: json['parentId'] as String?,
    createdById: json['createdById'] as String,
  );

  final String id;
  final String name;

  /// 공개 범위·구역 — 앱에는 개념이 없어 한 값으로만 쓴다 (backend-gap.md 53번)
  final String scope;
  final String space;

  /// 상위 폴더 — null 이면 최상위. **트리는 앱이 세운다**
  final String? parentId;

  /// 만든 사람 — 본인이나 관리자만 이름을 고치고 지울 수 있다
  final String createdById;
}

/// 문서함 파일 (서버 `DocumentOut`)
class Document {
  Document({
    required this.id,
    required this.name,
    required this.ext,
    required this.sizeBytes,
    required this.url,
    required this.scope,
    required this.space,
    required this.tags,
    required this.uploaderId,
    this.folderId,
    this.desc,
  });

  factory Document.fromJson(Map<String, dynamic> json) => Document(
    id: json['id'] as String,
    name: json['name'] as String,
    ext: json['ext'] as String? ?? '',
    sizeBytes: json['sizeBytes'] as int? ?? 0,
    url: json['url'] as String? ?? '',
    scope: json['scope'] as String? ?? '',
    space: json['space'] as String? ?? '',
    folderId: json['folderId'] as String?,
    tags: [
      for (final tag in (json['tags'] as List<dynamic>? ?? const []))
        tag as String,
    ],
    desc: json['desc'] as String?,
    uploaderId: json['uploaderId'] as String,
  );

  final String id;
  final String name;

  /// 확장자 (점 없이) — 아이콘·색을 고르는 데 쓴다
  final String ext;

  final int sizeBytes;

  /// 서명이 붙은 **상대 경로**(`/files/...?exp&sig`).
  /// 그대로는 못 부르고 서버 주소를 앞에 붙여야 한다 ([fileUrl])
  final String url;

  final String scope;
  final String space;

  /// 담긴 폴더 — null 이면 최상위
  final String? folderId;

  final List<String> tags;
  final String? desc;

  /// 올린 사람 — 본인이나 관리자만 고치고 지울 수 있다
  final String uploaderId;

  /// 바로 열 수 있는 파일 주소
  String get fileUrl => url.startsWith('http') ? url : '$apiBaseUrl$url';
}

/// `/folders` · `/documents` — 문서함
///
/// 폴더도 문서도 **만든 사람 또는 관리자(ADMIN·MASTER)만** 이름을 고치고 지운다.
/// 폴더를 지우면 **그 안의 문서도 같이 지워진다** (서버가 한꺼번에 처리한다).
class DocumentApi {
  DocumentApi._();

  static final _client = ApiClient.instance;

  /// 앱은 갈래를 안 나눠서 이 한 쌍만 쓴다 (backend-gap.md 53번)
  static const scope = '전사';
  static const space = '문서함';

  // ── 폴더 ──

  /// 이름순으로 **평평하게** 온다 — 트리는 `parentId` 로 앱이 세운다
  static Future<List<Folder>> folders() async {
    final rows = await _client.getList(
      '/folders',
      query: {'scope': scope, 'space': space},
    );
    return [
      for (final row in rows)
        Folder.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  static Future<Folder> createFolder({
    required String name,
    String? parentId,
  }) async {
    final data = await _client.post(
      '/folders',
      body: {
        'name': name,
        'scope': scope,
        'space': space,
        'parentId': ?parentId,
      },
    );
    return Folder.fromJson(data!);
  }

  /// 이름 바꾸기 — 서버가 받는 건 이름뿐이다.
  /// **폴더를 다른 폴더로 옮길 수는 없다** (backend-gap.md 52번)
  static Future<Folder> renameFolder(String id, {required String name}) async {
    final data = await _client.patch('/folders/$id', body: {'name': name});
    return Folder.fromJson(data!);
  }

  /// 지우기 — **안에 든 문서도 같이 지워진다**
  static Future<void> deleteFolder(String id) => _client.delete('/folders/$id');

  // ── 문서 ──

  /// 최신순. [folderId] 를 주면 그 폴더 것만 온다
  static Future<List<Document>> documents({String? folderId, String? q}) async {
    final rows = await _client.getList(
      '/documents',
      query: {'scope': scope, 'space': space, 'folderId': ?folderId, 'q': ?q},
    );
    return [
      for (final row in rows)
        Document.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 파일 올리기 — 멀티파트. [folderId] 가 null 이면 최상위에 담긴다
  static Future<Document> upload(
    String path, {
    required String filename,
    String? folderId,
    String? desc,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: filename),
      'scope': scope,
      'space': space,
      'name': filename,
      'folderId': ?folderId,
      'desc': ?desc,
    });
    final data = await _client.post('/documents', body: form);
    return Document.fromJson(data!);
  }

  /// 이름·설명 고치기.
  /// **다른 폴더로 옮길 수는 없다** — `folderId` 를 안 받는다 (backend-gap.md 52번)
  static Future<Document> updateDocument(
    String id, {
    String? name,
    String? desc,
  }) async {
    final data = await _client.patch(
      '/documents/$id',
      body: {'name': ?name, 'desc': ?desc},
    );
    return Document.fromJson(data!);
  }

  static Future<void> deleteDocument(String id) =>
      _client.delete('/documents/$id');
}
