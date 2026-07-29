import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // 앱이 폰 기준 세로 레이아웃이라 기본 창을 폰 비율로 띄운다
    var windowFrame = self.frame
    windowFrame.size = NSSize(width: 430, height: 900)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 360, height: 640)

    // 타이틀바를 앱 배경(흰색)과 한 몸처럼 보이게 한다
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.backgroundColor = NSColor.white

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
