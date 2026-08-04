import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// 화면 캡처 감지 — **iOS 는 막을 수 없다.**
  ///
  /// 애플이 스크린샷을 차단하는 API 를 안 준다 (안드로이드의 `FLAG_SECURE`,
  /// macOS 의 `sharingType` 에 해당하는 것이 없다). 그래서 두 가지만 한다.
  ///
  /// - **찍힌 뒤** 알려 준다 (`userDidTakeScreenshot`) — 못 막으니 남기기라도 한다
  /// - 녹화·미러링이 **도는 중**인지 알려 준다 (`isCaptured`) — Dart 가 가림막을 덮는다
  ///
  /// 보안 입력창 레이어에 화면을 넣어 스크린샷을 검게 만드는 편법이 있지만
  /// 안 쓴다 — 문서화 안 된 동작이라 iOS 업데이트에 깨지고,
  /// cupertino_native 네이티브 뷰(탭바·글래스 버튼)와 충돌한다.
  private var captureChannel: FlutterMethodChannel?

  /// MASTER 면 감시하지 않는다 — 켜져 있을 때만 신고가 나간다
  private var guarding = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HiFISCaptureGuard")
    else { return }

    let channel = FlutterMethodChannel(
      name: "com.hifis/capture",
      binaryMessenger: registrar.messenger()
    )
    captureChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setSecure":
        self?.guarding = (call.arguments as? Bool) ?? true
        // false = **못 막는다.** 감지만 한다 — Dart 가 이 값으로 갈린다
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let center = NotificationCenter.default
    center.addObserver(
      self,
      selector: #selector(onScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(onCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
  }

  @objc private func onScreenshot() {
    guard guarding else { return }
    captureChannel?.invokeMethod("onScreenshot", arguments: nil)
  }

  @objc private func onCaptureChanged() {
    guard guarding else { return }
    // 미러링·에어플레이도 여기 걸린다 — 화면이 다른 데로 나가는 건 매한가지다
    let capturing = UIScreen.screens.contains { $0.isCaptured }
    captureChannel?.invokeMethod("onCaptureChanged", arguments: capturing)
  }
}
