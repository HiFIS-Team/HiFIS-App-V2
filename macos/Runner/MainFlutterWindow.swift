import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // 데스크톱 비율 기본 창 — 콘텐츠는 Flutter 쪽에서 가운데 고정 폭으로 담는다.
    // 이전 실행의 창 크기를 복원하면 지정 크기가 무시되므로 복원을 끈다.
    self.isRestorable = false
    var windowFrame = self.frame
    windowFrame.size = NSSize(width: 1180, height: 800)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.center()
    self.minSize = NSSize(width: 480, height: 600)

    // 타이틀바를 앱 배경(흰색)과 한 몸처럼 보이게 한다
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.backgroundColor = NSColor.white

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 화면 캡처 방지 — MASTER 밑으로는 못 찍게 막는다.
    // `sharingType = .none` 이면 이 창이 화면 공유·녹화·캡처 API 에서 빠진다.
    // iOS 와 달리 실제로 막히므로 사후 신고를 할 일이 없다.
    let captureChannel = FlutterMethodChannel(
      name: "com.hifis/capture",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    captureChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setSecure":
        let on = (call.arguments as? Bool) ?? true
        self?.sharingType = on ? .none : .readOnly
        result(true)  // 실제로 막아 준다
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 푸시는 창이 아니라 **앱**에 오므로 AppDelegate 가 받는다.
    // 채널을 만들 수 있는 건 엔진을 든 이 쪽이라 여기서 건네준다.
    (NSApp.delegate as? AppDelegate)?
      .wirePush(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
