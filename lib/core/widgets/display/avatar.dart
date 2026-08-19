import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/staff.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../util/photo_cache.dart';

/// 이름 첫 글자 동그라미 — 색과 사진을 직원 명단에서 가져온다
///
/// [imageUrl] 을 안 주면 **이름으로 명단에서 찾는다** (색과 같은 길이다).
/// 아바타를 그리는 자리가 56곳인데 사진을 넘겨주던 곳은 4곳뿐이라,
/// 조직도 말고는 사진이 안 나왔다 — 그래서 여기서 찾게 했다.
///
/// 사진을 못 받아오면 첫 글자 동그라미로 떨어지므로, 로딩 중이나
/// 서명 만료 때도 자리가 안 빈다.
///
/// ## 사진은 [PhotoCache] 로 파일에 남긴다 (사내톡 사진과 같은 길)
///
/// 예전에는 `Image.network` 하나였는데, **화면을 옮겼다 오면 사진이 첫 글자로
/// 잠깐 바뀌었다 돌아왔다** (2026-08-19). 사진이 안 바뀌었는데도 그랬다.
///
/// 서버가 응답을 만들 때마다 서명(`?exp=..&sig=..`)을 **새로 찍는다** —
/// 가리키는 파일은 같은데 주소 글자가 매번 다르다. 플러터의 이미지 캐시는
/// 그 글자가 곧 열쇠라, 명단을 다시 받을 때마다(`ScreenRefresh`) 전부
/// 캐시 밖이 되어 **처음부터 다시 내려받았다.** 그동안이 첫 글자 동그라미다.
///
/// [PhotoCache] 는 서명을 뗀 **파일 이름**을 열쇠로 쓰고 디스크에 남기므로,
/// 탭을 옮겨도 앱을 껐다 켜도 첫 프레임부터 사진이 그대로 있다.
class Avatar extends StatefulWidget {
  Avatar({super.key, required this.name, this.size = 24, this.imageUrl});

  final String name;
  final double size;

  /// 명단에 없는 사람(초대 전 등)을 그릴 때만 직접 준다
  final String? imageUrl;

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  /// 받아 둔 사진 — 있으면 첫 프레임부터 그린다
  File? _file;

  /// 파일로 못 남겼다 — 그때만 예전처럼 서버에서 바로 그려 본다
  bool _failed = false;

  /// 지금 들고 있는 사진의 파일 이름 — 서명이 갈려도 같은 파일인지 가른다
  String? _key;

  /// 그릴 사진이 바뀌었으면 받기 시작한다 — **빌드 안에서 부른다**
  ///
  /// 여기서 `setState` 를 부르지 않는다 (빌드 도중이라 터진다). 값만 갈아 두고
  /// 지금 프레임이 그것을 그린다. 실제로 받아 와야 할 때만 나중에 `setState`.
  ///
  /// `didUpdateWidget` 이 아니라 여기인 이유 — 사진 주소는 [staffOf] 로 명단에서
  /// 찾는데, 그 함수가 명단을 통째로 다시 만든다. 빌드에서 이미 한 번 부르므로
  /// 여기서 받아 쓰면 **부르는 횟수가 안 는다.**
  void _sync(String? url) {
    final key = url == null || url.isEmpty ? null : PhotoCache.keyOf(url);
    if (key == _key) return; // 서명만 갈린 같은 사진 — 그대로 둔다
    _key = key;
    _file = null;
    _failed = false;
    if (url == null || url.isEmpty) return;

    // 예전에 받아 둔 것이면 여기서 바로 나온다 (깜빡임 없음)
    final saved = PhotoCache.ready(url);
    if (saved != null) {
      _file = saved;
      return;
    }
    PhotoCache.fetch(url).then((file) {
      // 받는 사이에 사진이 바뀌었으면 버린다 (늦게 온 것이 새것을 덮으면 안 된다)
      if (!mounted || key != _key) return;
      setState(() {
        _file = file;
        _failed = file == null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final person = staffOf(widget.name);
    final url = widget.imageUrl ?? person.imageUrl;
    _sync(url);

    final initial = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: person.color, shape: BoxShape.circle),
      child: Text(
        widget.name.characters.first,
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );

    final file = _file;
    if (file != null) {
      return ClipOval(
        child: Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => initial,
        ),
      );
    }

    // 파일로 못 남겼을 때만 서버에서 바로 그린다 — 예전 동작 그대로다
    if (_failed && url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => initial,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : initial,
        ),
      );
    }

    return initial;
  }
}

/// 참여자 아바타 겹쳐 보이기 (넘치면 +N)
class AvatarStack extends StatelessWidget {
  AvatarStack({super.key, required this.names, this.size = 22});

  final List<String> names;
  final double size;

  /// 이보다 많으면 나머지는 +N으로 접는다
  static const _max = 4;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(_max).toList();
    final rest = names.length - shown.length;
    final step = size * 0.72;

    return SizedBox(
      height: size,
      width: shown.length * step + (rest > 0 ? step + size * 0.4 : size - step),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                padding: EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Avatar(name: shown[i], size: size - 3),
              ),
            ),
          if (rest > 0)
            Positioned(
              left: shown.length * step,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                child: Text(
                  '+$rest',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
