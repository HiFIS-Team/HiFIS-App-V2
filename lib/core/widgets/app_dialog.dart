import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../util/platform.dart';

/// '전체 보기'처럼 목록을 통째로 여는 화면 띄우기
///
/// 폰은 오른쪽에서 밀려 들어오는 페이지로 연다.
/// 데스크톱은 콘텐츠를 통째로 덮으면 사이드바 맥락이 끊겨서, 가운데 큰 모달로 띄운다.
Future<T?> showFullPage<T>(BuildContext context, WidgetBuilder builder) {
  if (!isDesktop) {
    return Navigator.push<T>(context, CupertinoPageRoute(builder: builder));
  }
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => Center(child: _ModalFrame(builder: builder)),
  );
}

/// 데스크톱 모달 틀 — 창 크기에 맞춰 줄어드는 둥근 상자
class _ModalFrame extends StatelessWidget {
  _ModalFrame({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width - 160;
    final height = size.height - 120;

    return Container(
      width: width < 880 ? width : 880,
      height: height < 720 ? height : 720,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
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
