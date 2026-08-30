import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/work/workout_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/photo.dart';
import '../../core/util/photo_cache.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/input/pressable.dart';

/// 자료 묶음 하나를 고치는 동안 값을 들고 있는 상자
///
/// 사진·영상은 **고른 즉시 서버에 올려** 주소만 여기 담는다. 저장할 때 몰아
/// 올리면 영상 몇 개에 몇십 초가 걸려 화면이 멈춘 것처럼 보인다.
class MediaGroupEditor {
  MediaGroupEditor([MediaGroup? group])
    : items = [...?group?.items],
      feedback = TextEditingController(text: group?.feedback ?? '');

  final List<MediaItem> items;
  final TextEditingController feedback;

  bool get isEmpty => items.isEmpty && feedback.text.trim().isEmpty;

  MediaGroup toGroup() =>
      MediaGroup(items: List.of(items), feedback: feedback.text.trim());

  void dispose() => feedback.dispose();
}

/// 영상 확장자 — 이건 줄이지 않고 그대로 올린다
///
/// 종류를 정하는 건 서버지만, 앱도 알아야 한다. 영상을 사진 줄이는 길로 보내면
/// 디코딩에 실패해 원본이 그대로 나가는데 그 사이 몇 초를 그냥 버린다.
const _videoExts = {'mp4', 'mov', 'm4v', 'webm'};

/// 사진·영상을 골라 올린다 — 한 번에 여러 개
///
/// iOS 는 [FilePicker] 의 `compressionQuality` 가 0 보다 클 때만 사진첩 원본을
/// **호환 형식으로 바꿔** 준다 (HEIC→JPEG, HEVC→H.264). 이 값을 0 으로 두면
/// 아이폰에서 고른 사진이 .heic 로 나와 서버가 거른다.
Future<List<MediaItem>> pickWorkoutMedia(BuildContext context) async {
  final picked = await FilePicker.pickFiles(
    allowMultiple: true,
    type: isDesktop ? FileType.any : FileType.media,
    compressionQuality: isDesktop ? 0 : 100,
  );
  final files = picked?.files ?? const <PlatformFile>[];
  if (files.isEmpty) return const [];

  // 줄이기는 한 장씩 한다 — 여러 장을 한꺼번에 펼치면 메모리가 튄다.
  // 올리기는 같이 한다 (사내톡 사진과 같은 길이다).
  final ready = <(String path, String name, bool temp)>[];
  for (final file in files) {
    final path = file.path;
    if (path == null) continue;
    final ext = file.name.split('.').last.toLowerCase();
    if (_videoExts.contains(ext)) {
      ready.add((path, file.name, false));
      continue;
    }
    final (small, name) = await shrinkPhoto(path, file.name);
    ready.add((small, name, small != path));
  }
  if (ready.isEmpty) return const [];

  try {
    return await Future.wait([
      for (final (path, name, _) in ready)
        WorkoutApi.uploadMedia(path, filename: name),
    ]);
  } finally {
    // 줄이면서 만든 임시 파일은 성공하든 말든 치운다
    for (final (path, _, temp) in ready) {
      if (temp) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
    }
  }
}

/// 자료 묶음 목록 — 묶음마다 파일 몇 개와 그에 대한 한마디
///
/// **묶음으로 나누는 이유** — 영상 하나 올리고 그 밑에 한마디, 다시 사진 셋을
/// 올리고 또 한마디를 쓰는 식이라 자료와 말이 붙어 다녀야 한다. 한 덩어리로
/// 쌓아 두면 어느 말이 어느 영상에 대한 것인지 알 수 없다.
class MediaGroupList extends StatelessWidget {
  const MediaGroupList({
    super.key,
    required this.groups,
    required this.editable,
    required this.hint,
    required this.emptyText,
    this.onRemoveGroup,
    this.onRemoveItem,
  });

  final List<MediaGroupEditor> groups;
  final bool editable;

  /// 피드백 칸에 흐리게 뜨는 안내
  final String hint;

  final String emptyText;
  final void Function(int group)? onRemoveGroup;
  final void Function(int group, int item)? onRemoveItem;

  @override
  Widget build(BuildContext context) {
    final shown = editable
        ? groups
        : [
            for (final group in groups)
              if (!group.isEmpty) group,
          ];
    if (shown.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: AppDecorations.field(),
        child: Column(
          children: [
            Icon(CupertinoIcons.photo, size: 22, color: AppColors.gray400),
            const SizedBox(height: 8),
            Text(
              emptyText,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (!editable && groups[i].isEmpty)
            const SizedBox.shrink()
          else ...[
            if (i > 0) const SizedBox(height: 10),
            _GroupCard(
              group: groups[i],
              index: i,
              editable: editable,
              hint: hint,
              onRemove: onRemoveGroup == null ? null : () => onRemoveGroup!(i),
              onRemoveItem: onRemoveItem == null
                  ? null
                  : (item) => onRemoveItem!(i, item),
            ),
          ],
        ],
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.index,
    required this.editable,
    required this.hint,
    this.onRemove,
    this.onRemoveItem,
  });

  final MediaGroupEditor group;
  final int index;
  final bool editable;
  final String hint;
  final VoidCallback? onRemove;
  final void Function(int item)? onRemoveItem;

  @override
  Widget build(BuildContext context) {
    final feedback = group.feedback.text.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: AppDecorations.field(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${index + 1}번째 묶음',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (editable && onRemove != null)
                Pressable(
                  onTap: onRemove!,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      '묶음 삭제',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (group.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, box) {
                // 한 줄에 세 칸 — 우표만 하면 뭐를 찍었는지 안 보인다
                const gap = 8.0;
                final size = (box.maxWidth - gap * 2) / 3;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var i = 0; i < group.items.length; i++)
                      _Thumb(
                        item: group.items[i],
                        size: size,
                        onRemove: editable && onRemoveItem != null
                            ? () => onRemoveItem!(i)
                            : null,
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          if (editable)
            Container(
              padding: AppDecorations.fieldPaddingMultiline,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: group.feedback,
                style: AppTextStyles.body2,
                cursorColor: AppColors.primary,
                maxLines: 4,
                minLines: 2,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppTextStyles.body2.copyWith(
                    color: AppColors.gray400,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  counterText: '',
                ),
              ),
            )
          else
            Text(
              feedback.isEmpty ? '피드백 없음' : feedback,
              style: AppTextStyles.body2.copyWith(
                height: 1.6,
                color: feedback.isEmpty
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}

/// 자료 한 칸 — 사진은 미리보기, 영상은 재생 표시
class _Thumb extends StatefulWidget {
  const _Thumb({required this.item, required this.size, this.onRemove});

  final MediaItem item;
  final double size;
  final VoidCallback? onRemove;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo) return;
    // 아바타·사내톡 사진과 같은 길 — 한 번 받으면 다음부터 바로 뜬다
    final url = widget.item.url;
    _file = PhotoCache.ready(url);
    if (_file != null) return;
    PhotoCache.fetch(url).then((file) {
      if (!mounted) return;
      setState(() {
        _file = file;
        _failed = file == null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Pressable(
              onTap: () => openWorkoutMedia(context, widget.item),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _inner(),
              ),
            ),
          ),
          if (widget.onRemove case final remove?)
            Positioned(
              top: -6,
              right: -6,
              child: Pressable(
                onTap: remove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inner() {
    if (widget.item.isVideo) {
      return Center(
        child: Icon(
          CupertinoIcons.play_circle_fill,
          size: 34,
          color: AppColors.textTertiary,
        ),
      );
    }
    if (_file case final file?) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    if (_failed) return _fallback();
    return const Center(
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _fallback() => Center(
    child: Icon(CupertinoIcons.photo, size: 20, color: AppColors.gray400),
  );
}

/// 자료 크게 보기
///
/// **영상은 시스템 재생기로 넘긴다.** `video_player` 는 윈도우를 지원하지 않고
/// `media_kit` 은 여섯 플랫폼에 네이티브 의존을 더한다. 서버가 영상 확장자를
/// 내려받기가 아니라 재생으로 내보내 줘서(`INLINE_EXTS`) 브라우저에서 바로 돈다.
Future<void> openWorkoutMedia(BuildContext context, MediaItem item) async {
  if (!item.isVideo) {
    await showFullPage(context, (_) => _PhotoViewer(item: item));
    return;
  }
  final opened = await launchUrl(
    Uri.parse(item.fullUrl),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!opened && context.mounted) {
    AppToast.show(context, '영상을 열 수 있는 앱이 없어요');
  }
}

/// 사진 한 장 크게 — 손가락으로 키워 볼 수 있다
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.item});

  final MediaItem item;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _file = PhotoCache.ready(widget.item.url);
    if (_file != null) return;
    PhotoCache.fetch(widget.item.url).then((file) {
      if (!mounted) return;
      setState(() {
        _file = file;
        _failed = file == null;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(child: _body()),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          right: 12,
          child: Pressable(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _body() {
    if (_file case final file?) {
      return InteractiveViewer(
        maxScale: 4,
        child: Image.file(file, errorBuilder: (_, _, _) => _message()),
      );
    }
    if (_failed) return _message();
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }

  Widget _message() => Text(
    '사진을 불러오지 못했어요',
    style: AppTextStyles.body2.copyWith(color: Colors.white70),
  );
}
