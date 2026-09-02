import Flutter
import UIKit

/// 추첨 영상을 인스타그램으로 넘긴다.
///
/// 길이 둘인데 **어느 쪽이든 캡션은 사람이 인스타 안에서 쓴다.** 우리가 대신
/// 올리는 게 아니라서 심사가 없다.
///
/// | | 언제 | 어디로 떨어지나 |
/// |---|---|---|
/// | **공유 시트** | 늘 된다 (기본) | 인스타를 고르면 인스타가 릴스·스토리·피드를 묻는다 |
/// | 릴스 직행 | [metaAppId] 가 있을 때 | **릴스 작성 화면**이 영상을 물고 바로 열린다 |
///
/// 공유 시트는 **메타 앱 ID 가 필요 없다** — 그냥 파일을 넘기는 것이라
/// 인스타와 아무 약속이 없다. 직행은 인스타가 우리를 알아야 해서 ID 를 본다.
enum ReelsShare {
  private static let reels = URL(string: "instagram-reels://share")!

  /// 붙임판에 얹어 둘 시간 — 메타 문서가 5분을 쓴다
  private static let expiry: TimeInterval = 5 * 60

  static func wire(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.hifis/reels", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      // 공유 시트는 늘 있다 — 인스타가 안 깔려 있어도 시트는 뜬다
      case "available":
        result(true)

      case "share":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String
        else {
          result(false)
          return
        }
        result(share(path: path, appID: args["appId"] as? String ?? ""))

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func share(path: String, appID: String) -> Bool {
    let url = URL(fileURLWithPath: path)

    // ① 앱 ID 가 있으면 릴스 작성 화면으로 바로 — 시트를 한 번 덜 거친다
    if !appID.isEmpty,
       UIApplication.shared.canOpenURL(reels),
       let data = try? Data(contentsOf: url) {
      UIPasteboard.general.setItems(
        [["com.instagram.sharedSticker.backgroundVideo": data,
          "com.instagram.sharedSticker.appID": appID]],
        options: [.expirationDate: Date().addingTimeInterval(expiry)]
      )
      UIApplication.shared.open(reels, options: [:], completionHandler: nil)
      return true
    }

    // ② 없으면 공유 시트 — 여기서 인스타를 고르면 릴스로 갈 수 있다
    guard let host = top() else { return false }
    let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    // **아이패드에서는 이걸 안 주면 그냥 죽는다** — 시트가 어디서 나올지를
    // 모르면 UIKit 이 예외를 던진다. 아이폰은 무시된다
    if let pop = sheet.popoverPresentationController {
      pop.sourceView = host.view
      pop.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.maxY,
                              width: 0, height: 0)
      pop.permittedArrowDirections = []
    }
    host.present(sheet, animated: true)
    // **연 것까지만 참이다.** 올렸는지는 우리가 알 수 없다
    return true
  }

  /// 지금 화면 맨 위 — 여기서 시트를 띄운다
  ///
  /// `windows.first` 로 잡으면 안 된다. 다른 화면이 덮여 있으면 그 아래
  /// 컨트롤러에 띄우려다 아무것도 안 뜬다 (에러도 없다).
  private static func top() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
      ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    var vc = window?.rootViewController
    while let next = vc?.presentedViewController { vc = next }
    return vc
  }
}
