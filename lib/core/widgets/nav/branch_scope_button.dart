/// 헤더의 지점 고르개 — 업무·랭킹·조직도·근태가 같이 보는 값을 여기서 정한다
///
/// 알림 종·프로필과 한 줄에 서는 **글래스 아이콘 버튼**이다. 예전에는 화면마다
/// 고르개가 따로 있어서 (업무 왼쪽 위, 랭킹 왼쪽 위) 옆 화면으로 옮기면 다시
/// 전 지점으로 돌아갔고, 둘이 서로 다른 지점을 가리키기도 했다.
/// **여기 하나만 두고 모든 화면이 그 값을 따른다.**
///
/// **MASTER·ADMIN 에게만 뜬다** ([branchScopeVisible]). 나머지는 서버가 본인
/// 지점으로 고정해서 골라 봐야 바뀌는 것이 없다.
///
/// | | 어디에 |
/// |---|---|
/// | 폰 | **홈 탭에만** — 바코드가 서던 자리 (대표·관리자는 바코드가 없다) |
/// | 데스크톱 | 모든 화면 헤더 |
///
/// 아이폰에서도 cupertino_native 네이티브 메뉴는 안 쓴다 — 패키지가 메뉴를
/// 버튼 왼쪽에 붙여서 창 밖으로 새어 나간다. 안드로이드는 [GlassIconButton] 이
/// 알아서 블러 + 반투명 원으로 떨어져 같은 줄의 다른 버튼과 모양이 같다.
library;

import 'package:flutter/cupertino.dart';

import '../../api/staff/staff_api.dart';
import '../../data/branch_scope.dart';
import '../../data/staff_directory.dart';
import '../glass/glass_icon_button.dart';
import '../glass/glass_menu.dart';

class BranchScopeButton extends StatefulWidget {
  const BranchScopeButton({super.key, this.enabled = true});

  /// 바코드 오버레이가 떠 있을 때처럼 잠깐 못 누르게 할 때 false
  final bool enabled;

  @override
  State<BranchScopeButton> createState() => _BranchScopeButtonState();
}

class _BranchScopeButtonState extends State<BranchScopeButton> {
  /// 메뉴를 버튼 아래에 띄우려면 버튼 자리를 알아야 한다
  final _key = GlobalKey();

  /// 이미 떠 있는지 — 없으면 누를 때마다 하나씩 더 쌓인다 (사내톡에서 겪었다)
  bool _open = false;

  /// 세울 지점 — 조직도·업무 필터와 같은 기준
  ///
  /// **HQ는 안 세운다.** 지점이 아니라 전사이고, 이름이 하필 `전 지점` 이라
  /// 맨 위 '전 지점'과 글자가 겹친다.
  List<Branch> get _choices {
    final directory = StaffDirectory.instance;
    return [...directory.branches.where((branch) => !branch.isHq)]..sort(
      (a, b) =>
          directory.branchRank(a.id).compareTo(directory.branchRank(b.id)),
    );
  }

  Future<void> _openMenu() async {
    if (_open) return;
    _open = true;
    final choices = _choices;
    final selected = branchScope.value;
    final picked = await showGlassMenu<String>(
      context: context,
      anchorKey: _key,
      width: 230,
      // 머리말(`지점`)을 안 붙인다 — 고를 수 없는 줄인데 자리를 크게 차지한다
      items: [
        GlassMenuItem(
          // null 은 '안 골랐다'와 구분이 안 돼서 전체에 따로 값을 준다
          value: allBranchesLabel,
          label: allBranchesLabel,
          icon: CupertinoIcons.square_grid_2x2,
          selected: selected == null,
        ),
        for (final branch in choices)
          GlassMenuItem(
            value: branch.id,
            label: branch.name,
            icon: CupertinoIcons.building_2_fill,
            selected: selected == branch.id,
          ),
      ],
    );
    _open = false;
    if (!mounted || picked == null) return;
    branchScope.value = picked == allBranchesLabel ? null : picked;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: branchScope,
      builder: (context, selected, child) => GlassIconButton(
        key: _key,
        // 심볼이 바뀌어도 네이티브 버튼을 새로 만들지 않게 고정 식별자를 준다
        stableId: 'branch-scope',
        // 한 지점을 보는 중이면 채운 아이콘으로 바꾼다 — 버튼이 아이콘 하나라
        // 고른 지점 **이름**은 메뉴를 열어야 보인다. 최소한 "지금 걸려 있다"는
        // 것만이라도 버튼에서 알 수 있게 한다.
        symbol: selected == null ? 'building.2' : 'building.2.fill',
        enabled: widget.enabled,
        onPressed: _openMenu,
      ),
    );
  }
}
