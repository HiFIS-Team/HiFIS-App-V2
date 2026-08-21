part of 'document_screen.dart';

// ── 파일 미리보기 ──

/// 파일을 열었을 때 보여주는 창
///
/// 올린 이미지는 실제로 그려주고, 그 밖의 형식은 아직 뷰어가 없어
/// 파일 정보만 보여준다.
void _showFilePreview(
  BuildContext context,
  _Item item, {
  required VoidCallback onDownload,
}) {
  showAppDialog<void>(
    context,
    (context) => _FilePreviewCard(item: item, onDownload: onDownload),
  );
}

class _FilePreviewCard extends StatelessWidget {
  _FilePreviewCard({required this.item, required this.onDownload});

  final _Item item;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Container(
      width: dialogWidth(context, 420),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(item.kind.icon, size: 26, color: item.kind.color),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (item.canPreview)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: size.height * 0.5),
                // 방금 올린 것은 로컬 파일이 있어 서버를 안 거쳐도 된다.
                // 그 외에는 서명 주소로 받아 온다
                child: item.path != null
                    ? Image.file(
                        File(item.path!),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        // 파일이 지워졌거나 못 읽으면 자리만 채운다
                        errorBuilder: (context, error, stack) =>
                            _placeholder('이미지를 불러올 수 없어요'),
                      )
                    : Image.network(
                        item.url!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        errorBuilder: (context, error, stack) =>
                            _placeholder('이미지를 불러올 수 없어요'),
                      ),
              ),
            )
          else
            _placeholder('${item.kind.label}은 아직 미리보기를 지원하지 않아요'),
          SizedBox(height: 16),
          // 적어 둔 것이 있을 때만 — 안 적으면 이 두 줄이 아예 없다
          if (item.desc case final desc? when desc.isNotEmpty)
            _info('설명', desc),
          if (item.tags.isNotEmpty) _info('태그', item.tags.join(' · ')),
          _info('종류', item.kind.label),
          _info('크기', item.sizeLabel),
          if (item.updated != null) _info('수정한 날짜', item.updatedLabel),
          if (item.ownerId case final owner?)
            _info('올린 사람', _uploaderName(owner)),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '닫기',
                      style: AppTextStyles.body2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                // 미리보기가 안 되는 형식은 여기가 **유일한 출구**다
                child: Pressable(
                  onTap: () {
                    Navigator.pop(context);
                    onDownload();
                  },
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '내려받기',
                          style: AppTextStyles.body2.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String text) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: 40),
    decoration: BoxDecoration(
      color: AppColors.gray50,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.kind.icon, size: 34, color: AppColors.gray400),
        SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(fontSize: 12),
        ),
      ],
    ),
  );

  Widget _info(String label, String value) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body2.copyWith(fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}
