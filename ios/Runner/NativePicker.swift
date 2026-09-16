import Flutter
import SwiftUI
import UIKit

/// 날짜·시각 고르개를 **아래에서 올라오는 iOS 시트**로 띄운다 (2026-09-16 대표 요청)
///
/// Flutter 의 `showDatePicker`·`showTimePicker` 는 머티리얼 창이라 화면 한가운데
/// 떠오른다. 아이폰 사람은 **아래에서 올라오는 판**을 기대한다 — 캘린더·시계 앱이
/// 다 그 모양이다. 유리 버튼·탭바를 네이티브로 그리는 것과 같은 이유다.
///
/// `TeamFIS-App` 의 고르개(`ScheduleDetailScreen.datePicker`)와 같은 결이다 —
/// 날짜는 `.graphical`, 시각은 `.wheel`.
///
/// **아이폰에서만이다.** 안드로이드·맥·윈도우는 Dart 쪽이 예전 고르개로 떨어진다
/// ([native_picker.dart]).
enum NativePicker {
  /// 시트를 쓰려면 `UISheetPresentationController` 가 있어야 한다 (iOS 15+).
  /// 그 아래에서는 Dart 가 예전 고르개를 쓴다 — 전체 화면으로 덮으면 더 어색하다.
  private static var usable: Bool {
    if #available(iOS 15.0, *) { return true }
    return false
  }

  static func wire(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.hifis/picker", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "available":
        result(usable)

      case "time", "date":
        guard usable, let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "UNSUPPORTED", message: nil, details: nil))
          return
        }
        present(isTime: call.method == "time", args: args, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - 띄우기

  private static func present(
    isTime: Bool, args: [String: Any], result: @escaping FlutterResult
  ) {
    guard #available(iOS 15.0, *), let host = topViewController() else {
      result(FlutterError(code: "NO_WINDOW", message: nil, details: nil))
      return
    }

    let calendar = Calendar(identifier: .gregorian)
    let initial = parse(args["initial"] as? String, isTime: isTime) ?? Date()
    // **비어 있으면 열어 둔다** — 날짜 고르개만 범위를 받는다
    let range = bounds(args, isTime: isTime)

    // **고른 값을 계속 들고 있다가 닫힐 때 넘긴다.** iOS 고르개는 닫는 것이
    // 곧 고르는 것이다 — 취소·완료 바를 얹었더니 색이 갈리고 그 아래가 비었다.
    var picked = initial
    // 한 번만 돌려준다 — 안 막으면 `result` 를 두 번 불러 Flutter 가 경고를 낸다
    var answered = false
    let reply: () -> Void = {
      guard !answered else { return }
      answered = true
      result(format(picked, isTime: isTime))
    }

    let sheet = PickerSheet(
      isTime: isTime,
      initial: initial,
      range: range,
      calendar: calendar,
      accent: color(from: args["accent"] as? String),
      onChange: { picked = $0 }
    )

    let controller = UIHostingController(rootView: sheet)
    if let presentation = controller.sheetPresentationController {
      presentation.detents = detents(isTime: isTime)
      presentation.prefersGrabberVisible = true
      presentation.preferredCornerRadius = 22
    }
    // 아래로 끌어 내려도·바깥을 눌러도 답을 준다 — 안 주면 Dart 가 영영 기다린다
    controller.presentationController?.delegate = DismissRelay.install(on: controller, onDismiss: reply)
    host.present(controller, animated: true)
  }

  /// 시트 높이 — **고르개만큼만 잡는다**
  ///
  /// `.medium()` 은 화면의 절반이라, 휠(216pt)을 넣으면 **아래가 통째로 빈다**
  /// (2026-09-16 실제로 그렇게 떴다). iOS 16 부터는 높이를 직접 줄 수 있어서
  /// `TeamFIS-App` 이 쓰는 값(휠 260)을 그대로 쓴다.
  ///
  /// 그 아래(iOS 15)에는 `.medium()` 밖에 없다 — 빈 자리가 남지만 시트가
  /// 아예 없는 것보다 낫다.
  @available(iOS 15.0, *)
  private static func detents(isTime: Bool) -> [UISheetPresentationController.Detent] {
    if #available(iOS 16.0, *) {
      // 휠은 TeamFIS 와 같은 260, 달력은 한 달이 다 보이는 높이
      let height: CGFloat = isTime ? 260 : 430
      return [
        .custom(identifier: .init(isTime ? "hifis.time" : "hifis.date")) { context in
          // 작은 화면에서는 시트가 화면을 넘지 않게 한 번 더 자른다
          min(height, context.maximumDetentValue)
        }
      ]
    }
    // 달력은 절반으로 모자랄 수 있어 끌어올릴 자리를 같이 준다
    return isTime ? [.medium()] : [.medium(), .large()]
  }

  // MARK: - 값 옮기기

  private static func parse(_ raw: String?, isTime: Bool) -> Date? {
    guard let raw else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = isTime ? "HH:mm" : "yyyy-MM-dd"
    guard let parsed = formatter.date(from: raw) else { return nil }
    guard isTime else { return parsed }
    // 시각만 받으면 1970년으로 떨어진다 — 오늘 날짜에 시·분만 얹는다
    let parts = Calendar.current.dateComponents([.hour, .minute], from: parsed)
    return Calendar.current.date(
      bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: Date()
    )
  }

  private static func format(_ date: Date, isTime: Bool) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = isTime ? "HH:mm" : "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  private static func bounds(_ args: [String: Any], isTime: Bool) -> ClosedRange<Date>? {
    guard !isTime else { return nil }
    let first = parse(args["min"] as? String, isTime: false)
    let last = parse(args["max"] as? String, isTime: false)
    guard let first, let last, first <= last else { return nil }
    return first...last
  }

  /// `#RRGGBB` → 색. 못 읽으면 nil 이라 시스템 파랑으로 떨어진다
  private static func color(from hex: String?) -> Color? {
    guard var raw = hex else { return nil }
    raw = raw.replacingOccurrences(of: "#", with: "")
    guard raw.count == 6, let value = UInt32(raw, radix: 16) else { return nil }
    return Color(
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255
    )
  }

  private static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
    while let next = top?.presentedViewController { top = next }
    return top
  }
}

/// 아래로 끌어 내려 닫은 것도 '취소' 로 돌려준다
///
/// 델리게이트는 **약한 참조**라 그냥 넘기면 바로 사라진다. 띄운 컨트롤러에
/// 매달아 두어 시트가 살아 있는 동안 같이 산다.
private final class DismissRelay: NSObject, UIAdaptivePresentationControllerDelegate {
  private static var key: UInt8 = 0
  private let onDismiss: () -> Void

  private init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

  static func install(on host: UIViewController, onDismiss: @escaping () -> Void) -> DismissRelay {
    let relay = DismissRelay(onDismiss: onDismiss)
    objc_setAssociatedObject(host, &key, relay, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    return relay
  }

  func presentationControllerDidDismiss(_ controller: UIPresentationController) {
    onDismiss()
  }
}

/// 시트 안쪽 — **고르개 하나뿐이다**
///
/// `TeamFIS-App` 의 `ScheduleDetailScreen.timePicker` 를 그대로 가져왔다 —
/// 고르개 + `.padding()` + 높이 지정이 전부다.
///
/// **머리줄(취소·완료)을 안 둔다.** 처음에는 달았는데 셋이 한꺼번에 어긋났다
/// (2026-09-16) — 바 색이 시트와 갈리고, 바 아래가 비고, 그 빈 자리로 터치가
/// 새어 **뒤 화면이 같이 굴렀다.** iOS 고르개는 원래 닫는 것이 곧 고르는 것이다.
///
/// 그래서 **바닥을 시스템 배경으로 꽉 채운다.** 투명하게 두면 그 자리가 곧
/// 구멍이라 뒤로 터치가 지나간다.
private struct PickerSheet: View {
  let isTime: Bool
  let initial: Date
  let range: ClosedRange<Date>?
  let calendar: Calendar
  let accent: Color?
  let onChange: (Date) -> Void

  @State private var value: Date

  init(
    isTime: Bool, initial: Date, range: ClosedRange<Date>?,
    calendar: Calendar, accent: Color?, onChange: @escaping (Date) -> Void
  ) {
    self.isTime = isTime
    self.initial = initial
    self.range = range
    self.calendar = calendar
    self.accent = accent
    self.onChange = onChange
    _value = State(initialValue: initial)
  }

  var body: some View {
    picker
      .labelsHidden()
      .environment(\.calendar, calendar)
      // `.tint` 는 iOS 16 부터다 — 최소 배포가 14 라 옛 짝을 쓴다
      .accentColor(accent)
      .padding()
      // **꽉 채운다** — 남는 자리가 있으면 그리로 터치가 샌다
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(UIColor.systemBackground).ignoresSafeArea())
  }

  @ViewBuilder
  private var picker: some View {
    let bound = Binding(get: { value }, set: { value = $0; onChange($0) })
    if isTime {
      DatePicker("", selection: bound, displayedComponents: .hourAndMinute)
        .datePickerStyle(.wheel)
    } else if let range {
      DatePicker("", selection: bound, in: range, displayedComponents: .date)
        .datePickerStyle(.graphical)
    } else {
      DatePicker("", selection: bound, displayedComponents: .date)
        .datePickerStyle(.graphical)
    }
  }
}
