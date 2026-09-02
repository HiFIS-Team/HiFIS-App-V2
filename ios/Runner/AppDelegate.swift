import Flutter
import UIKit
import UserNotifications

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

  /// 푸시 알림 — 기기 토큰을 Dart 에 넘기고, 알림을 눌렀을 때 갈 곳을 알린다
  private var pushChannel: FlutterMethodChannel?

  /// Dart 쪽 수신 준비가 끝났는가
  ///
  /// 꺼져 있던 앱을 알림으로 켜면 **네이티브가 Dart 보다 먼저** 눌린 것을 안다.
  /// 그 사이에 온 것은 [pendingLink] 에 담아 두고 준비되면 건넨다.
  private var dartReady = false

  /// 아직 Dart 에 못 넘긴 링크 (앱이 꺼져 있을 때 눌린 알림)
  private var pendingLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 눌린 알림을 받으려면 **엔진이 뜨기 전에** 잡아 둬야 한다.
    // 여기서 안 걸면 꺼져 있던 앱을 알림으로 켰을 때 그 알림이 그냥 사라진다.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 리퀴드 글래스 면 — 검색바·입력바·상단 블러가 쓴다 ([GlassSurface.swift])
    if let glassRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "HiFISGlassSurface") {
      glassRegistrar.register(
        GlassSurfaceFactory(messenger: glassRegistrar.messenger()),
        withId: "com.hifis/glass_surface"
      )
    }

    // 앱 테마 → 창 외관
    //
    // **네이티브 뷰는 앱 안 테마를 모른다.** iOS 시스템 외관만 본다. 앱은
    // 자체 토글(`AppColors.setDark`)로 도는데 시스템이 라이트면 **다크 모드에서
    // 유리가 밝은 유리로 그려진다** (실제로 겪었다 — 상단 띠가 흰색으로 떴다).
    //
    // 뷰마다 손보지 않고 **창 하나**에 건다. 그러면 우리 유리뿐 아니라
    // `CNButton`·`CNTabBar`·시스템 메뉴·키보드까지 전부 따라온다.
    if let themeRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "HiFISTheme") {
      let channel = FlutterMethodChannel(
        name: "com.hifis/theme", binaryMessenger: themeRegistrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "setDark", let dark = call.arguments as? Bool else {
          result(FlutterMethodNotImplemented)
          return
        }
        let style: UIUserInterfaceStyle = dark ? .dark : .light
        // 창을 못 찾으면 조용히 넘어간다 — 색이 어긋날 뿐 앱은 돈다
        for scene in UIApplication.shared.connectedScenes {
          (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
        result(nil)
      }
    }

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
        // **지금 상태를 한 번 알려 준다.** `capturedDidChange` 는 이름 그대로
        // *바뀔 때만* 오므로, 녹화를 켠 채 앱을 껐다 켜면 알림이 안 온다 —
        // 새 프로세스는 `recording` 이 false 로 시작해서 **커버가 안 뜬 채로
        // 화면이 그대로 나간다.** 실제로 이 자리가 뚫렸다 (2026-08-12).
        self?.pushCaptureState()
        // false = **못 막는다.** 감지만 한다 — Dart 가 이 값으로 갈린다
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    wirePush(messenger: registrar.messenger())
    ReelsShare.wire(messenger: registrar.messenger())

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
    pushCaptureState()
  }

  /// 지금 화면이 밖으로 나가는 중인지 Dart 에 알린다
  ///
  /// 감시를 끌 때(MASTER)는 무조건 `false` 가 간다 — 안 보내면 앞사람 세션에서
  /// 올라간 커버가 대표 화면에 그대로 남는다.
  private func pushCaptureState() {
    // 미러링·에어플레이도 여기 걸린다 — 화면이 다른 데로 나가는 건 매한가지다
    let capturing = guarding && UIScreen.screens.contains { $0.isCaptured }
    captureChannel?.invokeMethod("onCaptureChanged", arguments: capturing)
  }

  // MARK: - 푸시 알림

  private func wirePush(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.hifis/push", binaryMessenger: messenger)
    pushChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      // Dart 가 받을 준비를 마쳤다 — 그동안 담아 둔 링크를 흘려보낸다
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

  /// 알림 권한을 묻고, 허락하면 애플에 기기를 등록한다
  ///
  /// 이미 한 번 물어본 뒤라면 시스템 창이 다시 뜨지 않는다 — 그때의 답이
  /// 그대로 돌아온다. 그래서 로그인할 때마다 불러도 사용자에게는 조용하다.
  private func requestPush(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current()
      .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
        DispatchQueue.main.async {
          // 거절해도 등록은 해 둔다 — 나중에 설정에서 켜면 바로 온다
          UIApplication.shared.registerForRemoteNotifications()
          result(granted)
        }
      }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(
      application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    pushChannel?.invokeMethod(
      "onToken",
      arguments: ["token": token, "platform": "IOS", "sandbox": usesSandboxPush]
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    // 시뮬레이터·기기 설정 문제 등 — 앱은 그대로 돌아간다 (앱 안 알림함은 살아 있다)
    NSLog("푸시 등록 실패: \(error.localizedDescription)")
  }

  /// **앱을 보고 있을 때도 배너를 띄운다** (2026-08-19 대표 요청)
  ///
  /// 이걸 구현 안 하면 iOS 가 앞에 떠 있는 앱에는 알림을 **안 보여준다**
  /// (앱 안 알림함·배지에는 그대로 쌓인다). 사내톡을 보고 있는데 다른 방에
  /// 온 메시지를 모르는 것이 그 때문이었다.
  ///
  /// `.list` 를 같이 주는 이유 — 배너만 주면 못 보고 지나쳤을 때 알림 센터에
  /// 안 남는다. 소리·배지도 뒤에서 온 것과 같게 맞춘다.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound, .badge])
  }

  /// 알림을 눌렀다 — 그 알림이 가리키는 화면으로 보낸다
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    deliver(link: response.notification.request.content.userInfo["link"] as? String)
    super.userNotificationCenter(
      center, didReceive: response, withCompletionHandler: completionHandler)
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

  /// 이 빌드가 애플의 **개발용** 푸시 서버를 쓰는가
  ///
  /// 서버가 보낼 주소를 이 값으로 고른다 (`api.sandbox.push.apple.com` ↔
  /// `api.push.apple.com`). 틀리면 `BadDeviceToken` 으로 조용히 안 간다.
  ///
  /// **디버그 빌드인지로 가르면 틀린다** — 폰에 까는 `flutter run --release`
  /// 도 개발 서명이라 sandbox 토큰이다. 그래서 서명에 실제로 박힌
  /// `aps-environment` 를 읽는다.
  private var usesSandboxPush: Bool {
    guard
      let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
      let data = try? Data(contentsOf: url),
      // 서명 봉투(DER) 안에 plist 가 통째로 들어 있다 — 그 구간만 잘라 낸다
      let text = String(data: data, encoding: .isoLatin1),
      let start = text.range(of: "<?xml"),
      let end = text.range(of: "</plist>"),
      let plist = String(text[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
      let root = try? PropertyListSerialization.propertyList(from: plist, format: nil)
        as? [String: Any],
      let entitlements = root["Entitlements"] as? [String: Any],
      let environment = entitlements["aps-environment"] as? String
    else {
      // 프로필이 없으면 앱스토어에서 받은 빌드다 — 운영 주소가 맞다
      return false
    }
    return environment == "development"
  }
}
