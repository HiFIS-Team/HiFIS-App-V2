import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../util/platform.dart';
import '../input/app_button.dart';
import '../input/pressable.dart';
import '../../theme/app_shadows.dart';
import '../../util/app_route.dart';

/// '전체 보기'처럼 목록을 통째로 여는 화면 띄우기
///
/// 폰은 오른쪽에서 밀려 들어오는 페이지로 연다.
/// 데스크톱은 콘텐츠를 통째로 덮으면 사이드바 맥락이 끊겨서, 가운데 큰 모달로 띄운다.
Future<T?> showFullPage<T>(BuildContext context, WidgetBuilder builder) {
  if (!isDesktop) {
    return Navigator.push<T>(context, appRoute(builder));
  }
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => Center(child: _ModalFrame(builder: builder)),
  );
}

/// 데스크톱 모달 틀 — 창 크기에 맞춰 줄어드는 둥근 상자
///
/// 안에 들어오는 건 폰 폭에 맞춰 만든 세로 목록이라, 창을 가득 채우면
/// 글줄이 늘어지고 아래가 텅 빈다. 읽기 좋은 폭으로 잡고 높이도 창보다
/// 확실히 작게 둬서 뒤 화면이 비쳐 모달로 읽히게 한다.
class _ModalFrame extends StatelessWidget {
  _ModalFrame({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width - 200;
    final height = size.height - 200;

    return Container(
      width: width < 620 ? width : 620,
      height: height < 600 ? height : 600,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.modal,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        // 안에 들어오는 화면은 자기 Scaffold를 그대로 쓴다
        child: ColoredBox(color: AppColors.background, child: builder(context)),
      ),
    );
  }
}

/// 앱 공통 팝업 띄우기
///
/// 폰에서도 그대로 쓸 수 있게 네 가지를 처리한다.
/// - 키보드가 올라오면 그만큼 위로 민다
/// - 내용이 짧으면 가운데, 화면보다 길면 팝업이 스크롤된다
/// - 폭은 [dialogWidth]로 화면 안에 들어오게 줄인다
/// - 팝업 바깥 빈 곳을 누르면 닫힌다
Future<T?> showAppDialog<T>(BuildContext context, WidgetBuilder builder) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          // 스크롤 영역이 화면을 덮고 있어 기본 barrier 탭이 닿지 않는다.
          // 바깥을 눌러 닫는 동작을 여기서 직접 처리한다.
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: ConstrainedBox(
              // 내용이 짧을 때 가운데로 오게 뷰포트만큼 최소 높이를 준다
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: GestureDetector(
                  // 팝업 안쪽 탭은 삼켜서 닫히지 않게 한다
                  onTap: () {},
                  child: Material(
                    type: MaterialType.transparency,
                    child: builder(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 팝업 폭 — 데스크톱은 설계 폭 그대로, 폰은 화면에 맞춰 줄인다
double dialogWidth(BuildContext context, double design) {
  final fit = MediaQuery.sizeOf(context).width - 40;
  return fit < design ? fit : design;
}

/// 한 번 더 묻는 팝업 — 되돌리기 어려운 동작 앞에 쓴다
///
/// 눌렀는지(true) 여부를 돌려준다. 바깥을 눌러 닫으면 false다.
/// [destructive]를 켜면 확인 버튼이 빨간색이 된다.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  bool destructive = false,
}) async {
  final result = await showAppDialog<bool>(
    context,
    (context) => _ConfirmCard(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class _ConfirmCard extends StatelessWidget {
  _ConfirmCard({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return isAndroid ? _material(context) : _apple(context);
  }

  /// 애플·윈도우 — 가운데 정렬 제목에 채운 버튼 둘 (지금까지와 똑같다)
  Widget _apple(BuildContext context) {
    return Container(
      width: dialogWidth(context, 320),
      padding: EdgeInsets.fromLTRB(24, 26, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.title3),
          if (message != null) ...[
            SizedBox(height: 10),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: cancelLabel,
                  onTap: () => Navigator.pop(context, false),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: confirmLabel,
                  filled: true,
                  // 되돌리기 어려운 동작이면 빨갛게
                  color: destructive ? AppColors.error : null,
                  onTap: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 안드로이드 — Material 3 알림창
  ///
  /// 제목·본문은 **왼쪽**, 버튼은 **오른쪽 아래에 글자만**. 되돌리는 쪽(취소)이
  /// 왼쪽, 확정하는 쪽이 오른쪽이다. 모서리는 28.
  ///
  /// 애플은 가운데 정렬에 채운 버튼 둘인데, 그대로 두면 안드로이드에서
  /// **iOS 알림창을 보는 느낌**이 난다.
  Widget _material(BuildContext context) {
    return Container(
      width: dialogWidth(context, 340),
      padding: EdgeInsets.fromLTRB(24, 24, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text(title, style: AppTextStyles.title3),
          ),
          if (message != null) ...[
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                message!,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _TextAction(
                label: cancelLabel,
                color: AppColors.textSecondary,
                onTap: () => Navigator.pop(context, false),
              ),
              SizedBox(width: 4),
              _TextAction(
                label: confirmLabel,
                color: destructive ? AppColors.error : AppColors.primary,
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Material 알림창의 글자 버튼 — 눌리는 자리가 글자보다 넉넉해야 한다
class _TextAction extends StatelessWidget {
  _TextAction({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        label,
        style: AppTextStyles.body1.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
