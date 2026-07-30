import 'package:flutter/material.dart';

/// 앱 공통 팝업 띄우기
///
/// 폰에서도 그대로 쓸 수 있게 세 가지를 처리한다.
/// - 키보드가 올라오면 그만큼 위로 민다
/// - 내용이 짧으면 가운데, 화면보다 길면 팝업이 스크롤된다
/// - 폭은 [dialogWidth]로 화면 안에 들어오게 줄인다
Future<T?> showAppDialog<T>(BuildContext context, WidgetBuilder builder) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: ConstrainedBox(
            // 내용이 짧을 때 가운데로 오게 뷰포트만큼 최소 높이를 준다
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: builder(context),
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
