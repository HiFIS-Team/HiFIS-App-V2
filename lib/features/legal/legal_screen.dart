import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/platform.dart';
import '../../core/widgets/editor/markdown_view.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/phone_scaffold.dart';

/// 앱이 보여주는 법적 고지 문서
///
/// 원문은 `assets/legal/*.md` 하나뿐이다. 웹에 올릴 공개 페이지도 같은 파일을
/// 쓰므로 사본을 만들지 않는다 — 두 벌이 되면 반드시 한쪽만 고쳐진다.
enum LegalDocument {
  terms('이용약관', 'assets/legal/terms.md', 'TERMS', '2026-08-01'),
  privacy('개인정보처리방침', 'assets/legal/privacy.md', 'PRIVACY', '2026-08-19');

  const LegalDocument(this.title, this.asset, this.wire, this.version);

  final String title;
  final String asset;

  /// 서버 `docType` (`POST /employees/me/consents`)
  final String wire;

  /// 동의 이력에 남길 문서 버전 — **md 파일 첫머리의 `시행일` 과 같아야 한다**
  ///
  /// 문서를 고치면 여기도 같이 올린다. 안 올리면 옛 버전에 동의한 것으로
  /// 남아서, 나중에 재동의를 받아야 할 때 누가 안 봤는지 가릴 수 없다.
  final String version;
}

/// 전문 보기 — 폰은 밀려 들어오는 화면, PC는 가운데 모달
Future<void> showLegalDocument(BuildContext context, LegalDocument document) =>
    showFullPage<void>(context, (_) => LegalScreen(document: document));

class LegalScreen extends StatefulWidget {
  LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late final Future<String> _source = rootBundle.loadString(
    widget.document.asset,
  );

  /// 문서 본문 — 로딩 중에는 빈 화면을 둔다 (에셋이라 순식간에 끝난다)
  Widget _body({required EdgeInsets padding}) {
    return FutureBuilder<String>(
      future: _source,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
        return SingleChildScrollView(
          padding: padding,
          child: MarkdownView(source: snapshot.data!),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(28, 24, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.document.title,
                    style: AppTextStyles.title2,
                  ),
                ),
                Pressable(
                  onTap: () => Navigator.pop(context),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.close_rounded,
                      size: 21,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body(padding: EdgeInsets.fromLTRB(28, 8, 28, 28))),
        ],
      );
    }

    return PhoneDetailScaffold(
      title: widget.document.title,
      // 로그인 전에도 열리는 화면이라 하단 탭바가 없다 — 안전 영역만 피한다
      child: _body(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          MediaQuery.paddingOf(context).bottom + 40,
        ),
      ),
    );
  }
}
