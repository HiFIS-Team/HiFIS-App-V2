import Cocoa
import FlutterMacOS
import UserNotifications

/// macOS 의 `FlutterAppDelegate` 는 iOS 쪽과 달리 알림 델리게이트가 **아니다.**
/// 그래서 여기서 직접 그 역할을 받는다 (아래 `didReceive` 에 `override` 가 없는 이유).
@main
class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate {
  /// 푸시 알림 — iOS 와 같은 채널(`com.hifis/push`)을 쓴다.
  ///
  /// 창은 [MainFlutterWindow] 가 만들지만 **알림은 앱 단위**라 여기서 받는다.
  /// 채널은 창이 만들어 [wirePush] 로 건네준다.
  private var pushChannel: FlutterMethodChannel?

  /// Dart 쪽 수신 준비가 끝났는가 (iOS 와 같은 이유 — 그 쪽 주석 참고)
  private var dartReady = false

  /// 아직 Dart 에 못 넘긴 링크
  private var pendingLink: String?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // 눌린 알림을 받으려면 먼저 잡아 둬야 한다
    UNUserNotificationCenter.current().delegate = self
    super.applicationDidFinishLaunching(notification)
  }

  // MARK: - 푸시 알림

  func wirePush(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.hifis/push", binaryMessenger: messenger)
    pushChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "ready":
        self?.dartReady = true
        self?.flushPendingLink()
        result(nil)
      case "register":
        self?.requestPush(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func requestPush(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current()
      .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
        DispatchQueue.main.async {
          NSApplication.shared.registerForRemoteNotifications()
          result(granted)
        }
      }
  }

  // **`super` 를 부르지 않는다.** macOS 의 `FlutterAppDelegate` 는 이 둘을
  // 구현하지 않아서, 부르면 실행 중에 `unrecognized selector` 로 앱이 죽는다
  // (컴파일은 통과한다 — 실제로 겪었다). iOS 는 UIKit 쪽이 구현하고 있어 다르다.
  override func application(
    _ application: NSApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    pushChannel?.invokeMethod(
      "onToken",
      arguments: ["token": token, "platform": "MACOS", "sandbox": usesSandboxPush]
    )
  }

  override func application(
    _ application: NSApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("푸시 등록 실패: \(error.localizedDescription)")
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    deliver(link: response.notification.request.content.userInfo["link"] as? String)
    completionHandler()
  }

  private func deliver(link: String?) {
    guard let link, !link.isEmpty else { return }
    guard dartReady, let channel = pushChannel else {
      pendingLink = link
      return
    }
    channel.invokeMethod("onTap", arguments: link)
  }

  private func flushPendingLink() {
    guard let link = pendingLink else { return }
    pendingLink = nil
    pushChannel?.invokeMethod("onTap", arguments: link)
  }

  /// 이 빌드가 애플의 **개발용** 푸시 서버를 쓰는가 (iOS 쪽 같은 이름 참고)
  ///
  /// macOS 는 두 가지가 iOS 와 다르다 — 프로필이 번들 안에
  /// `embedded.provisionprofile` 로 들어가고, 엔타이틀먼트 키에
  /// `com.apple.developer.` 가 앞에 붙는다.
  private var usesSandboxPush: Bool {
    let url = Bundle.main.bundleURL.appendingPathComponent("Contents/embedded.provisionprofile")
    guard
      let data = try? Data(contentsOf: url),
      let text = String(data: data, encoding: .isoLatin1),
      let start = text.range(of: "<?xml"),
      let end = text.range(of: "</plist>"),
      let plist = String(text[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
      let root = try? PropertyListSerialization.propertyList(from: plist, format: nil)
        as? [String: Any],
      let entitlements = root["Entitlements"] as? [String: Any],
      let environment = entitlements["com.apple.developer.aps-environment"] as? String
    else {
      return false
    }
    return environment == "development"
  }
}
