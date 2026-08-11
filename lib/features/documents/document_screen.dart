import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/docs/document_api.dart';
import '../../core/data/current_user.dart';
import '../../core/data/staff.dart';
import '../../core/data/staff_directory.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/empty_state.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/widgets/feedback/skeleton.dart';

part 'document_models.dart';
part 'document_sidebar.dart';
part 'document_toolbar.dart';
part 'document_grid.dart';
part 'document_list.dart';
part 'document_dialogs.dart';
part 'document_preview.dart';
part 'document_move.dart';

/// 문서함 화면
///
/// 컴퓨터의 파일 탐색기처럼 폴더를 만들어 문서를 담아둔다.
/// 맥 파인더의 구조를 따라 좌측에 위치·폴더 목록, 우측에 현재 폴더의
/// 내용을 보여주고, 아이콘 보기와 목록 보기를 오갈 수 있다.
///
/// 서버는 폴더와 문서를 평평하게 주고, 트리는 앱이 세운다 ([_buildTree]).
class DocumentScreen extends StatefulWidget {
  DocumentScreen({super.key});

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  /// 지금 열려 있는 폴더까지의 경로 (첫 칸은 항상 최상위)
  final List<_Item> _path = [_root];

  /// 좌측에서 고른 위치 (폴더를 직접 열면 [_Place.all]로 돌아온다)
  _Place _place = _Place.all;

  /// 목록에서 고른 항목 — 이름 바꾸기·삭제의 대상
  _Item? _selected;

  /// true면 목록 보기, false면 아이콘 보기
  bool _listView = false;

  /// 파일을 끌어와 창 위에 올려둔 상태
  bool _dragging = false;

  /// 서버에 올리는 중 — 여러 개면 한 개씩 올라간다
  bool _uploading = false;

  /// 올리는 일이 몇 겹 겹쳐 있는지. 폴더째 올리면 폴더 만들기 + 폴더마다 파일
  /// 올리기가 중첩돼서, 단순 bool 이면 중간에 알약이 껌뻑인다
  int _busy = 0;

  /// 파일을 받아 오는 중 — 큰 파일이면 시간이 걸린다
  bool _downloading = false;

  void _beginBusy() {
    if (_busy++ == 0) setState(() => _uploading = true);
  }

  void _endBusy() {
    if (--_busy == 0 && mounted) setState(() => _uploading = false);
  }

  bool _loading = _treeScope != _scope;

  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _loadTree();
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _loading = false);
  }

  _Item get _current => _path.last;

  /// 좌측 트리에서 펼쳐둔 폴더
  final Set<_Item> _expanded = {};

  // ── 이동 ──

  void _open(_Item item) {
    if (!item.isFolder) {
      _showFilePreview(context, item, onDownload: () => _download(item));
      return;
    }
    setState(() {
      _place = _Place.all;
      _path.add(item);
      _selected = null;
      _query = '';
    });
  }

  /// 브레드크럼에서 [index] 칸으로 되돌아간다
  void _goTo(int index) {
    setState(() {
      _place = _Place.all;
      _path.removeRange(index + 1, _path.length);
      _selected = null;
    });
  }

  void _goUp() {
    if (_path.length > 1) _goTo(_path.length - 2);
  }

  /// 갈래를 바꾸면 트리를 통째로 다시 받는다 — 전사와 개인은 다른 목록이다
  ///
  /// **여기서는 [_loading] 을 켜지 않는다.** 그러면 사이드바까지 스피너로
  /// 통째로 갈렸다가 돌아와서 화면이 깜빡인다. 고른 칸은 바로 칠해지고
  /// 목록만 새 것이 오는 순간 갈린다.
  Future<void> _pickScope(DocScope scope) async {
    if (scope == _scope) return;
    setState(() {
      _scope = scope;
      // 목록이 오기 전에도 경로 줄 첫 칸이 바로 바뀌게 한다
      _root.name = scope.label;
      _place = _Place.all;
      _path.removeRange(1, _path.length);
      _expanded.clear();
      _selected = null;
      _query = '';
    });
    await _load();
  }

  /// 좌측 위치를 고르면 경로는 최상위로 되돌린다
  void _pickPlace(_Place place) {
    setState(() {
      _place = place;
      _path.removeRange(1, _path.length);
      _selected = null;
      _query = '';
    });
  }

  /// 좌측 트리에서 폴더를 고르면 그 폴더까지의 경로를 통째로 세운다
  void _jumpTo(List<_Item> path) {
    setState(() {
      _place = _Place.all;
      _path
        ..removeRange(1, _path.length)
        ..addAll(path);
      _selected = null;
      _query = '';
    });
  }

  // ── 편집 ──

  Future<void> _newFolder() async {
    final name = await _askName(context, title: '새 폴더', confirm: '만들기');
    if (name == null || !mounted) return;

    // 위치 보기 중에 만들면 최상위에 생긴다
    final target = _place == _Place.all ? _current : _root;
    try {
      final created = await DocumentApi.createFolder(
        scope: _scope,
        name: name,
        // 최상위는 서버에서 부모가 없다
        parentId: target.id.isEmpty ? null : target.id,
      );
      if (!mounted) return;
      final folder = _Item.folder(
        name: created.name,
        id: created.id,
        ownerId: created.createdById,
        updated: created.updatedAt ?? created.createdAt,
      );
      setState(() {
        target.children!.add(folder);
        _selected = folder;
      });
      AppToast.show(context, '폴더를 만들었어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  /// 컴퓨터에서 파일을 골라 지금 폴더에 담는다
  Future<void> _upload() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: '문서함에 올릴 파일 선택',
      allowMultiple: true,
    );
    if (result == null || !mounted) return;

    // 위치 보기 중에 올리면 최상위에 담긴다
    final target = _place == _Place.all ? _current : _root;
    await _uploadPaths([
      for (final picked in result.files)
        if (picked.path case final path?) (path, picked.name),
    ], target);
  }

  /// 창에 끌어다 놓은 것들을 담는다 (데스크톱 전용)
  ///
  /// 폴더를 놓으면 **안쪽 구조를 그대로** 가져온다 — 폴더는 `/folders/tree` 로
  /// 한 번에 만들고(중간에 실패해도 반쯤 남지 않는다), 파일은 제자리에 올린다.
  Future<void> _drop(List<String> paths) async {
    final target = _place == _Place.all ? _current : _root;
    final files = <(String, String)>[];
    final folders = <String>[];

    for (final path in paths) {
      final name = path.split(Platform.pathSeparator).last;
      // 맥의 .DS_Store 같은 숨김 파일은 건너뛴다
      if (name.startsWith('.')) continue;
      if (Directory(path).existsSync()) {
        folders.add(path);
      } else {
        files.add((path, name));
      }
    }

    if (folders.isNotEmpty) await _dropFolders(folders, target);
    if (!mounted) return;
    await _uploadPaths(files, target);
  }

  /// 끌어다 놓은 폴더들을 구조째 담는다
  Future<void> _dropFolders(List<String> paths, _Item target) async {
    _beginBusy();
    var added = 0;
    try {
      // 1) 폴더 구조만 먼저 훑어서 한 번에 만든다
      final created = await DocumentApi.createFolderTree(
        [for (final path in paths) _scanFolder(Directory(path))],
        scope: _scope,
        parentId: target.id.isEmpty ? null : target.id,
      );
      if (!mounted) return;

      // 2) 만들어진 id 를 로컬 경로에 짝지어 트리에 반영한다
      final byPath = <String, _Item>{};
      for (var i = 0; i < created.length; i++) {
        _graftFolder(created[i], Directory(paths[i]), target, byPath);
      }
      setState(() {});

      // 3) 폴더마다 그 안의 파일을 올린다.
      //    폴더 수만큼 알림이 뜨면 시끄러워서 여기서 한 번에 알린다
      for (final entry in byPath.entries) {
        if (!mounted) return;
        added += await _uploadPaths(
          _filesIn(Directory(entry.key)),
          entry.value,
          announce: false,
        );
      }
      if (mounted) {
        AppToast.show(context, '폴더 ${byPath.length}개 · 파일 $added개를 담았어요');
      }
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    _endBusy();
  }

  /// 디렉터리를 재귀로 훑어 폴더 구조만 뽑는다 (파일은 뒤에 따로 올린다)
  FolderTreeNode _scanFolder(Directory dir) {
    final name = dir.path.split(Platform.pathSeparator).last;
    final children = [
      for (final entry in dir.listSync())
        if (entry is Directory &&
            !entry.path.split(Platform.pathSeparator).last.startsWith('.'))
          _scanFolder(entry),
    ];
    return FolderTreeNode(name, children);
  }

  /// 서버가 돌려준 id 트리를 화면 트리에 붙이면서 `로컬 경로 → 항목` 을 모은다
  ///
  /// 하위끼리는 **이름으로** 짝짓는다. `listSync()` 순서가 두 번 부를 때
  /// 같다는 보장이 없어서, 차례로 맞추면 엉뚱한 폴더에 파일이 들어갈 수 있다.
  void _graftFolder(
    FolderTreeResult created,
    Directory dir,
    _Item parent,
    Map<String, _Item> byPath,
  ) {
    final folder = _Item.folder(
      name: created.name,
      id: created.id,
      ownerId: currentUser?.id,
      updated: DateTime.now(),
    );
    parent.children!.add(folder);
    byPath[dir.path] = folder;

    final madeByName = {
      for (final child in created.children) child.name: child,
    };
    for (final entry in dir.listSync()) {
      if (entry is! Directory) continue;
      final name = entry.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.')) continue;
      if (madeByName[name] case final made?) {
        _graftFolder(made, entry, folder, byPath);
      }
    }
  }

  /// 그 디렉터리 **바로 아래**의 파일들 (하위 폴더 것은 그 폴더가 맡는다)
  List<(String, String)> _filesIn(Directory dir) => [
    for (final entry in dir.listSync())
      if (entry is File)
        if (entry.path.split(Platform.pathSeparator).last case final name
            when !name.startsWith('.'))
          (entry.path, name),
  ];

  /// 고른 파일들을 하나씩 올린다 — 하나가 실패해도 나머지는 계속 간다.
  /// 담은 개수를 돌려준다 (폴더째 올릴 때 합쳐서 한 번에 알리려고)
  Future<int> _uploadPaths(
    List<(String, String)> files,
    _Item target, {
    bool announce = true,
  }) async {
    if (files.isEmpty) return 0;
    _beginBusy();

    var added = 0;
    Object? failure;
    for (final (path, name) in files) {
      try {
        final uploaded = await DocumentApi.upload(
          path,
          scope: _scope,
          filename: name,
          folderId: target.id.isEmpty ? null : target.id,
        );
        if (!mounted) return added;
        setState(() {
          // 방금 고른 파일이라 서버를 안 거치고도 미리보기가 된다
          target.children!.add(_itemOf(uploaded, path: path));
        });
        added++;
      } catch (error) {
        failure = error;
      }
    }

    _endBusy();
    if (!mounted) return added;
    setState(() => _place = _Place.all);
    if (announce && added > 0) AppToast.show(context, '$added개 파일을 올렸어요');
    if (failure != null) AppToast.show(context, messageOf(failure));
    return added;
  }

  Future<void> _rename(_Item item) async {
    if (!item.canEdit) {
      AppToast.show(context, '올린 사람만 이름을 바꿀 수 있어요');
      return;
    }
    final name = await _askName(
      context,
      title: '이름 바꾸기',
      confirm: '바꾸기',
      initial: item.name,
    );
    if (name == null || !mounted) return;

    final before = item.name;
    setState(() => item.name = name);
    try {
      if (item.isFolder) {
        await DocumentApi.updateFolder(item.id, name: name);
      } else {
        await DocumentApi.updateDocument(item.id, name: name);
      }
      if (mounted) setState(() => item.updated = DateTime.now());
    } catch (error) {
      if (!mounted) return;
      setState(() => item.name = before);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 설명·태그 고치기 — 서버가 문서에만 준다
  ///
  /// 검색이 이름뿐 아니라 이 둘도 훑어서, 파일 이름이 `scan_0421.pdf` 여도
  /// `계약서` 로 찾아진다.
  Future<void> _editInfo(_Item item) async {
    if (item.isFolder) return;
    if (!item.canEdit) {
      AppToast.show(context, '올린 사람만 고칠 수 있어요');
      return;
    }
    final info = await _askInfo(context, item);
    if (info == null || !mounted) return;

    final beforeDesc = item.desc;
    final beforeTags = item.tags;
    setState(() {
      item.desc = info.desc.isEmpty ? null : info.desc;
      item.tags = info.tags;
    });
    try {
      await DocumentApi.updateDocument(
        item.id,
        desc: info.desc,
        tags: info.tags,
      );
      if (mounted) setState(() => item.updated = DateTime.now());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        item.desc = beforeDesc;
        item.tags = beforeTags;
      });
      AppToast.show(context, messageOf(error));
    }
  }

  /// 끌어다 놓은 항목을 그 폴더로 옮긴다
  ///
  /// **화면을 먼저 옮기고 서버에 보낸다** — 놓자마자 자리가 바뀌어야 옮긴 것처럼
  /// 보인다. 실패하면 원래 자리로 되돌린다 (즐겨찾기 별과 같은 방식).
  Future<void> _move(_Item item, _Item folder) async {
    if (!item.canEdit) {
      AppToast.show(context, '올린 사람만 옮길 수 있어요');
      return;
    }
    final from = _parentOf(_root, item);
    if (from == null || !_canDropInto(item, folder)) return;

    setState(() {
      from.children!.remove(item);
      folder.children!.add(item);
      _selected = item;
    });

    try {
      // 최상위로 뺄 때는 빈 문자열이다 (null 은 "안 건드림")
      final parentId = folder.id.isEmpty ? '' : folder.id;
      if (item.isFolder) {
        await DocumentApi.updateFolder(item.id, parentId: parentId);
      } else {
        await DocumentApi.updateDocument(item.id, folderId: parentId);
      }
      if (mounted) setState(() => item.updated = DateTime.now());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        folder.children!.remove(item);
        from.children!.add(item);
      });
      AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _delete(_Item item) async {
    if (!item.canEdit) {
      AppToast.show(context, '올린 사람만 지울 수 있어요');
      return;
    }
    // **파일도 똑같이 묻는다.** 예전에는 폴더만 물어서, 같은 메뉴의 같은 '삭제'
    // 인데 폴더는 확인이 뜨고 파일은 그냥 사라졌다.
    //
    // 폴더는 지우면 **하위 폴더와 그 안의 문서까지** 서버에서 같이 지워져서
    // 무엇이 딸려 가는지를 따로 알려 준다.
    final nested =
        item.isFolder && item.children!.any((child) => child.isFolder);
    final ok = await showConfirmDialog(
      context,
      title: item.isFolder
          ? "'${item.name}' 폴더를 지울까요?"
          : "'${item.name}' 을 지울까요?",
      message: item.isFolder
          ? (nested ? '안에 든 하위 폴더와 문서까지 모두 지워져요.' : '폴더 안에 든 문서도 같이 지워져요.')
          : '지우면 되돌릴 수 없어요.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok || !mounted) return;

    try {
      if (item.isFolder) {
        await DocumentApi.deleteFolder(item.id);
      } else {
        await DocumentApi.deleteDocument(item.id);
      }
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
      return;
    }
    if (!mounted) return;

    final parent = _parentOf(_root, item) ?? _current;
    setState(() {
      parent.children?.remove(item);
      _expanded.remove(item);
      if (_selected == item) _selected = null;
      // 열어둔 폴더를 지웠으면 그 위로 빠져나온다
      final index = _path.indexOf(item);
      if (index > 0) _path.removeRange(index, _path.length);
    });
    AppToast.show(context, '${item.name}을(를) 삭제했어요');
  }

  /// 즐겨찾기 — 서버에 **사람마다 따로** 남는다
  ///
  /// 별은 누르는 순간 바뀌어야 해서 먼저 칠하고 서버에 보낸다.
  /// 실패하면 되돌린다.
  Future<void> _toggleStar(_Item item) async {
    // 서버는 문서에만 즐겨찾기를 준다
    if (item.isFolder) {
      AppToast.show(context, '폴더는 즐겨찾기에 못 담아요');
      return;
    }

    final next = !item.starred;
    setState(() => item.starred = next);
    try {
      await (next
          ? DocumentApi.favorite(item.id)
          : DocumentApi.unfavorite(item.id));
    } catch (error) {
      if (!mounted) return;
      setState(() => item.starred = !next);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 파일을 컴퓨터에 내려받는다
  ///
  /// 서버가 원본 이름으로 내려주지만 **어디에 둘지는 사람이 고른다** —
  /// 데스크톱에서 저장 위치를 안 묻고 받아 두면 어디 갔는지 알 수 없다.
  Future<void> _download(_Item item) async {
    if (item.isFolder) return;

    final target = await FilePicker.saveFile(
      dialogTitle: '저장할 위치를 고르세요',
      fileName: item.name,
    );
    if (target == null || !mounted) return;

    setState(() => _downloading = true);
    try {
      final bytes = await DocumentApi.download(item.id);
      await File(target).writeAsBytes(bytes);
      if (mounted) AppToast.show(context, '${item.name}을(를) 저장했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
    if (mounted) setState(() => _downloading = false);
  }

  // ── 우클릭 메뉴 ──

  /// 항목을 우클릭 — 고른 뒤 그 항목에 대한 메뉴를 띄운다
  void _itemMenu(_Item item, Offset position) {
    setState(() => _selected = item);
    _showDocumentMenu(context, position, [
      _MenuEntry(
        label: item.isFolder ? '열기' : '미리보기',
        icon: item.isFolder
            ? Icons.folder_open_rounded
            : Icons.visibility_rounded,
        onTap: () => _open(item),
      ),
      if (!item.isFolder)
        _MenuEntry(
          label: '내려받기',
          icon: Icons.download_rounded,
          onTap: () => _download(item),
        ),
      _MenuEntry(
        label: '이름 바꾸기',
        icon: Icons.drive_file_rename_outline_rounded,
        onTap: () => _rename(item),
      ),
      if (!item.isFolder)
        _MenuEntry(
          label: '설명·태그',
          icon: Icons.label_outline_rounded,
          onTap: () => _editInfo(item),
        ),
      if (!item.isFolder)
        _MenuEntry(
          label: item.starred ? '즐겨찾기 해제' : '즐겨찾기에 추가',
          icon: item.starred ? Icons.star_rounded : Icons.star_border_rounded,
          onTap: () => _toggleStar(item),
        ),
      _MenuEntry.divider(),
      _MenuEntry(
        label: '삭제',
        icon: Icons.delete_outline_rounded,
        danger: true,
        onTap: () => _delete(item),
      ),
    ]);
  }

  /// 빈 곳을 우클릭 — 폴더 만들기와 보기 전환
  void _blankMenu(Offset position) {
    setState(() => _selected = null);
    _showDocumentMenu(context, position, [
      _MenuEntry(
        label: '새 폴더',
        icon: Icons.create_new_folder_rounded,
        onTap: _newFolder,
      ),
      _MenuEntry(label: '파일 올리기', icon: Icons.upload_rounded, onTap: _upload),
      _MenuEntry.divider(),
      _MenuEntry(
        label: _listView ? '아이콘 보기' : '목록 보기',
        icon: _listView ? Icons.grid_view_rounded : Icons.list_rounded,
        onTap: () => setState(() => _listView = !_listView),
      ),
    ]);
  }

  // ── 보여줄 목록 ──

  List<_Item> get _visible {
    final list = switch (_place) {
      _Place.all => [..._current.children!],
      // 위치 보기는 폴더 구조와 상관없이 조건에 맞는 파일을 그러모은다
      _Place.recent =>
        _collect(_root).where((i) => !i.isFolder).toList()
          // 손댄 시각이 늦은 것부터. 시각이 없는 건 뒤로 민다
          ..sort((a, b) {
            final left = a.updated, right = b.updated;
            if (left == null || right == null) {
              return left == null ? (right == null ? 0 : 1) : -1;
            }
            return right.compareTo(left);
          }),
      _Place.starred => _collect(_root).where((i) => i.starred).toList(),
    };

    final query = _query.trim();
    // 이름뿐 아니라 설명·태그도 훑는다 — `scan_0421.pdf` 를 `계약서` 로 찾는 자리다
    final filtered = query.isEmpty
        ? list
        : list.where((i) => i.matches(query)).toList();

    if (_place == _Place.recent) return filtered.take(30).toList();

    // 파인더처럼 폴더가 먼저, 그다음 이름순
    filtered.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SkeletonTwoPane(rows: 7, filter: false);
    }

    final items = _visible;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 220,
            child: ColoredBox(
              color: AppColors.surface,
              child: _Sidebar(
                scope: _scope,
                place: _place,
                current: _current,
                expanded: _expanded,
                onPickScope: _pickScope,
                onPickPlace: _pickPlace,
                onJump: _jumpTo,
                onToggleExpand: (folder) => setState(() {
                  if (!_expanded.remove(folder)) _expanded.add(folder);
                }),
                onMove: _move,
              ),
            ),
          ),
          Container(width: 1, color: AppColors.gray100),
          Expanded(
            // 창에 파일을 끌어다 놓으면 지금 폴더에 담긴다 (데스크톱 전용)
            child: DropTarget(
              onDragEntered: (_) => setState(() => _dragging = true),
              onDragExited: (_) => setState(() => _dragging = false),
              onDragDone: (detail) {
                setState(() => _dragging = false);
                _drop([for (final file in detail.files) file.path]);
              },
              child: Stack(
                children: [
                  _pane(items),
                  if (_dragging) _DropOverlay(folder: _current.name),
                  // 여러 개면 한 개씩 올라가서 시간이 걸린다 — 진행 중임을 알린다
                  if (_uploading || _downloading)
                    Positioned(
                      right: 24,
                      bottom: 24,
                      child: _UploadingChip(
                        label: _uploading ? '올리는 중…' : '받는 중…',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 툴바 + 본문 + 상태 줄
  Widget _pane(List<_Item> items) {
    return Column(
      children: [
        _Toolbar(
          place: _place,
          path: _path,
          query: _query,
          listView: _listView,
          selected: _selected,
          canGoUp: _place == _Place.all && _path.length > 1,
          onGoUp: _goUp,
          onCrumb: _goTo,
          onMove: _move,
          onQuery: (v) => setState(() => _query = v),
          onToggleView: () => setState(() => _listView = !_listView),
          onNewFolder: _newFolder,
          onUpload: _upload,
          onRename: () => _rename(_selected!),
          onDelete: () => _delete(_selected!),
        ),
        Container(height: 1, color: AppColors.gray100),
        Expanded(
          // 항목 바깥 빈 곳을 누르면 선택을 푼다 (파인더와 같게).
          // 항목 위의 탭은 항목 쪽이 먼저 가져가므로 여기까지 안 온다.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _selected = null),
            onSecondaryTapDown: (d) => _blankMenu(d.globalPosition),
            child: items.isEmpty
                ? _Empty(place: _place, searching: _query.isNotEmpty)
                : _listView
                ? _ListBody(
                    items: items,
                    selected: _selected,
                    onMove: _move,
                    canDrag: _place == _Place.all,
                    onSelect: (i) => setState(() => _selected = i),
                    onOpen: _open,
                    onStar: _toggleStar,
                    onDownload: _download,
                    onRename: _rename,
                    onDelete: _delete,
                    onMenu: _itemMenu,
                  )
                : _GridBody(
                    items: items,
                    selected: _selected,
                    onMove: _move,
                    canDrag: _place == _Place.all,
                    onSelect: (i) => setState(() => _selected = i),
                    onOpen: _open,
                    onStar: _toggleStar,
                    onDownload: _download,
                    onRename: _rename,
                    onDelete: _delete,
                    onMenu: _itemMenu,
                  ),
          ),
        ),
        _StatusBar(items: items, selected: _selected),
      ],
    );
  }
}

/// 파일을 끌어와 창 위에 올렸을 때 덮이는 안내막
class _DropOverlay extends StatelessWidget {
  _DropOverlay({required this.folder});

  final String folder;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: AppColors.primary.withValues(alpha: 0.08),
        padding: EdgeInsets.all(16),
        child: DottedBorderBox(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.file_download_rounded,
                size: 40,
                color: AppColors.primary,
              ),
              SizedBox(height: 12),
              Text(
                '여기에 놓으면 담겨요',
                style: AppTextStyles.title3.copyWith(color: AppColors.primary),
              ),
              SizedBox(height: 4),
              Text(
                '$folder 폴더로 들어갑니다',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 점선 테두리 상자 — 놓을 자리를 표시한다
class DottedBorderBox extends StatelessWidget {
  DottedBorderBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Center(child: child),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  static const _dash = 8.0;
  static const _gap = 6.0;
  static const _radius = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(_radius)),
      );

    // 경로를 잘라 점선으로 그린다 (Flutter에는 점선 테두리가 없다)
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}
