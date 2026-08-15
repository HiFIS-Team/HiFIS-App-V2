import Flutter
import UIKit

/// 리퀴드 글래스 **면** — 검색바·입력바·상단 블러가 깔고 앉는 판
///
/// 버튼·탭바·메뉴는 `cupertino_native` 가 네이티브로 그려 주는데 **면은 없었다.**
/// 그래서 그 셋만 Flutter `BackdropFilter` 로 흉내 내고 있었다 (재질이 달라서
/// 나란히 두면 티가 났다). 이 뷰가 그 자리를 애플이 그리는 진짜 유리로 바꾼다.
///
/// ```
/// iOS 26+   UIGlassEffect          ← 스위프트 앱이 쓰는 그것
/// 그 아래    UIBlurEffect(.systemThinMaterial)   ← 예전 재질
/// 애플 아님  Dart 쪽에서 BackdropFilter 로 떨어진다 (여기 안 온다)
/// ```
///
/// **글래스는 자기 뒤를 샘플링한다.** Flutter 콘텐츠가 이 뷰 뒤에 오게
/// 두어야 비친다 — Dart 에서 `Stack` 의 위 레이어로 놓는 이유다.
///
/// ⚠️ 이건 네이티브 뷰라 **`BackdropFilter` 형제와 같은 `Row` 에 두면 안 된다.**
/// 탭이 안 먹는데 에러도 로그도 안 난다 (CLAUDE.md 참고).
class GlassSurfacePlatformView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let effectView: UIVisualEffectView

  /// 지금 걸려 있는 값 — 같은 값이 다시 오면 뷰를 안 건드린다.
  /// 스크롤 한 프레임마다 `update` 가 오는 자리라 이게 없으면 매 프레임 재적용된다.
  private var currentRadius: CGFloat = 0
  private var currentTint: UIColor?
  private var currentInteractive = false

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    container = UIView(frame: frame)
    effectView = UIVisualEffectView(frame: container.bounds)
    super.init()

    container.backgroundColor = .clear
    container.clipsToBounds = true
    // 면은 배경이다 — 터치는 위에 얹힌 Flutter 위젯(입력칸·버튼)이 받아야 한다.
    // 안 끄면 검색바를 눌러도 키보드가 안 올라온다.
    container.isUserInteractionEnabled = false
    effectView.isUserInteractionEnabled = false
    effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.addSubview(effectView)

    let dict = args as? [String: Any] ?? [:]
    apply(
      radius: CGFloat(dict["radius"] as? Double ?? 0),
      tint: Self.color(dict["tint"]),
      interactive: dict["interactive"] as? Bool ?? false,
      force: true
    )

    // 뷰마다 채널을 따로 판다 — 화면에 여러 장이 떠 있어도 섞이지 않는다
    let channel = FlutterMethodChannel(
      name: "com.hifis/glass_surface_\(viewId)", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, call.method == "update",
        let a = call.arguments as? [String: Any]
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.apply(
        radius: CGFloat(a["radius"] as? Double ?? Double(self.currentRadius)),
        tint: Self.color(a["tint"]) ?? self.currentTint,
        interactive: a["interactive"] as? Bool ?? self.currentInteractive,
        force: false
      )
      result(nil)
    }
  }

  func view() -> UIView { container }

  private func apply(radius: CGFloat, tint: UIColor?, interactive: Bool, force: Bool) {
    if !force, radius == currentRadius, tint == currentTint, interactive == currentInteractive {
      return
    }
    currentRadius = radius
    currentTint = tint
    currentInteractive = interactive

    container.layer.cornerRadius = radius
    container.layer.cornerCurve = .continuous

    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect(style: .regular)
      // 누르면 유리가 눌리는 반응 — 검색바처럼 누르는 면에만 켠다
      glass.isInteractive = interactive
      glass.tintColor = tint
      effectView.effect = glass
      // 유리의 굴절은 자기 모서리를 따라간다 — 컨테이너만 깎으면 안쪽이 각지게 남는다
      effectView.layer.cornerRadius = radius
      effectView.layer.cornerCurve = .continuous
      effectView.clipsToBounds = true
    } else {
      // 26 아래 — 예전 재질. 유리가 아니라 반투명 블러다
      effectView.effect = UIBlurEffect(style: .systemThinMaterial)
      effectView.layer.cornerRadius = radius
      effectView.layer.cornerCurve = .continuous
      effectView.clipsToBounds = true
    }
  }

  /// Dart 가 보내는 ARGB 정수 → UIColor (null 이면 색을 안 입힌다)
  private static func color(_ value: Any?) -> UIColor? {
    guard let n = value as? NSNumber else { return nil }
    let v = n.intValue
    return UIColor(
      red: CGFloat((v >> 16) & 0xFF) / 255.0,
      green: CGFloat((v >> 8) & 0xFF) / 255.0,
      blue: CGFloat(v & 0xFF) / 255.0,
      alpha: CGFloat((v >> 24) & 0xFF) / 255.0
    )
  }
}

class GlassSurfaceFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    GlassSurfacePlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }
}
