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

    super.awakeFromNib()
  }
}
