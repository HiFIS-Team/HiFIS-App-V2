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
    this.createdAt,
    this.updatedAt,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
    id: json['id'] as String,
    name: json['name'] as String,
    scope: json['scope'] as String? ?? '',
    space: json['space'] as String? ?? '',
    parentId: json['parentId'] as String?,
    createdById: json['createdById'] as String,
    createdAt: _time(json['createdAt']),
    updatedAt: _time(json['updatedAt']),
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

  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// 폴더째 올릴 때 넘기는 트리 한 칸 (서버 `FolderTreeNode`)
class FolderTreeNode {
  FolderTreeNode(this.name, [this.children = const []]);

  final String name;
  final List<FolderTreeNode> children;

  Map<String, dynamic> toJson() => {
    'name': name,
    'children': [for (final child in children) child.toJson()],
  };
}

/// 만들어진 폴더 트리 (서버 `FolderTreeNodeOut`) — 새 id 가 들어 있다
class FolderTreeResult {
  FolderTreeResult({
    required this.id,
    required this.name,
    required this.children,
  });

  factory FolderTreeResult.fromJson(Map<String, dynamic> json) =>
      FolderTreeResult(
        id: json['id'] as String,
        name: json['name'] as String,
        children: [
          for (final child in (json['children'] as List<dynamic>? ?? const []))
            FolderTreeResult.fromJson((child as Map).cast<String, dynamic>()),
        ],
      );

  final String id;
  final String name;
  final List<FolderTreeResult> children;
}

/// 문자열 시각을 로컬 시간으로 (서버는 UTC 로 준다)
DateTime? _time(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

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
    required this.favoritedByMe,
    this.folderId,
    this.desc,
    this.createdAt,
    this.updatedAt,
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
    favoritedByMe: json['favoritedByMe'] as bool? ?? false,
    createdAt: _time(json['createdAt']),
    updatedAt: _time(json['updatedAt']),
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

  /// 내가 즐겨찾기 했는지 — **사람마다 따로** 남는다
  final bool favoritedByMe;

  final DateTime? createdAt;
  final DateTime? updatedAt;

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

  /// 폴더 여러 겹을 **한 번에** 만든다 — 폴더째 끌어다 놓을 때 쓴다
  ///
  /// 서버가 한 트랜잭션으로 만들고 **만들어진 id 를 같은 트리 모양으로** 돌려준다.
  /// 앱은 그 id 로 파일을 제자리에 넣는다. 나눠 부르면 중간에 실패했을 때
  /// 반쯤 만들어진 폴더가 남는데, 이 길은 통째로 되돌아간다.
  static Future<List<FolderTreeResult>> createFolderTree(
    List<FolderTreeNode> nodes, {
    String? parentId,
  }) async {
    final rows = await _client.postList(
      '/folders/tree',
      body: {
        'scope': scope,
        'space': space,
        'parentId': ?parentId,
        'nodes': [for (final node in nodes) node.toJson()],
      },
    );
    return [
      for (final row in rows)
        FolderTreeResult.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// 이름 바꾸기 · 다른 폴더로 옮기기
  ///
  /// [parentId] 에 빈 문자열을 주면 최상위로 뺀다 (null 은 "안 건드림").
  static Future<Folder> updateFolder(
    String id, {
    String? name,
    String? parentId,
  }) async {
    final data = await _client.patch(
      '/folders/$id',
      body: {
        'name': ?name,
        if (parentId != null) 'parentId': parentId.isEmpty ? null : parentId,
      },
    );
    return Folder.fromJson(data!);
  }

  /// 지우기 — **안에 든 문서도, 하위 폴더도 같이 지워진다**
  static Future<void> deleteFolder(String id) => _client.delete('/folders/$id');

  // ── 문서 ──

  /// 최신순. [folderId] 를 주면 그 폴더 것만 온다
  static Future<List<Document>> documents({
    String? folderId,
    String? q,
    bool? favorite,
  }) async {
    final rows = await _client.getList(
      '/documents',
      query: {
        'scope': scope,
        'space': space,
        'folderId': ?folderId,
        'q': ?q,
        'favorite': ?favorite,
      },
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

  /// 이름·설명 고치기 · 다른 폴더로 옮기기
  ///
  /// [folderId] 에 빈 문자열을 주면 최상위로 뺀다 (null 은 "안 건드림").
  static Future<Document> updateDocument(
    String id, {
    String? name,
    String? desc,
    String? folderId,
  }) async {
    final data = await _client.patch(
      '/documents/$id',
      body: {
        'name': ?name,
        'desc': ?desc,
        if (folderId != null) 'folderId': folderId.isEmpty ? null : folderId,
      },
    );
    return Document.fromJson(data!);
  }

  static Future<void> deleteDocument(String id) =>
      _client.delete('/documents/$id');

  /// 즐겨찾기 — 사람·문서당 한 행이라 여러 번 눌러도 같다 (멱등)
  static Future<void> favorite(String id) =>
      _client.post('/documents/$id/favorite');

  static Future<void> unfavorite(String id) =>
      _client.delete('/documents/$id/favorite');

  /// 파일 받기 — 서버가 원래 이름으로 내려준다
  ///
  /// `DocumentOut.url` 로도 받아지지만 그건 **서명이 7일 뒤 만료**된다.
  /// 이 길은 만료가 없어서 오래 띄워둔 화면에서도 된다.
  static Future<List<int>> download(String id) =>
      _client.getBytes('/documents/$id/download');
}
