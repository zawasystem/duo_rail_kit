import Flutter
import UIKit

/// Bridges Flutter custom rails to `UITraitCollection.verticalBarEdge` (iOS 27.1+).
///
/// Payload: `{"edge": String, "statusBarHidden": Bool, "sequence": Int}`.
/// - `edge` is physical "left"/"right", or "none" when unavailable or unspecified.
///   Convert leading/trailing using the same trait collection's layout direction.
/// - `statusBarHidden` comes from the window scene, defaulting to false. A safe-area
///   column can remain present while its status display is hidden. `statusBarFrame`
///   does not describe that display's extent, so it cannot replace this flag.
/// - `sequence` increases for every payload. Dart accepts only newer values because
///   query replies and trait events can arrive out of order.
///
/// Observe relevant trait changes and emit `edgeChanged` when the payload changes.
/// Observation starts on `getEdge`: the Flutter view controller may not exist at
/// plugin registration. Dart also queries after metrics changes and app resume.
/// Status-bar visibility is sampled, not observed independently; a visibility-only
/// change can remain stale until the next query or trait event. Dart normalizes
/// the flag to false when no vertical edge exists to avoid irrelevant rebuilds.
///
/// Generated plugin registration installs this class; the registrar retains its
/// method-call delegate. `test/channel_name_source_test.dart` checks the channel
/// contract but does not replace native compilation or runtime verification.
public final class DuoRailKitPlugin: NSObject, FlutterPlugin {
  /// Must match Dart's `VerticalBarEdge.channel`.
  static let channelName = "com.zawasystem.fleet/vertical_bar_edge"

  private let channel: FlutterMethodChannel
  private let registrar: FlutterPluginRegistrar

  /// Reattach observation when the Flutter view controller changes.
  private weak var observedViewController: UIViewController?

  /// Last payload without its sequence, used to suppress duplicate events.
  private var lastValue: [String: AnyHashable]?

  /// Last emitted sequence number.
  private var sequence = 0

  init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
    self.channel = channel
    self.registrar = registrar
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = DuoRailKitPlugin(channel: channel, registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Platform-channel calls arrive on the main thread; UIKit observation is main-actor isolated.
    MainActor.assumeIsolated {
      switch call.method {
      case "getEdge":
        let viewController = registrar.viewController
        observe(viewController)
        let value = DuoRailKitPlugin.value(of: viewController)
        lastValue = value
        result(stamped(value))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @MainActor
  private func observe(_ viewController: UIViewController?) {
    guard let viewController, viewController !== observedViewController else { return }
    guard #available(iOS 27.1, *) else { return }
    observedViewController = viewController
    // UIKit ties observation to the view controller lifetime; no explicit cancellation token is needed.
    viewController.registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
      [weak self] (changed: UIViewController, _: UITraitCollection) in
      self?.send(DuoRailKitPlugin.value(of: changed))
    }
  }

  @MainActor
  private func send(_ value: [String: AnyHashable]) {
    // A relevant trait change need not change the resulting payload.
    guard value != lastValue else { return }
    lastValue = value
    channel.invokeMethod("edgeChanged", arguments: stamped(value))
  }

  /// Adds the next sequence number to a payload.
  @MainActor
  private func stamped(_ value: [String: AnyHashable]) -> [String: AnyHashable] {
    sequence += 1
    var stamped = value
    stamped["sequence"] = sequence
    return stamped
  }

  /// Includes visibility in both duplicate detection and sequence ordering.
  @MainActor
  static func value(of viewController: UIViewController?) -> [String: AnyHashable] {
    [
      "edge": edgeName(of: viewController?.traitCollection),
      "statusBarHidden": viewController?.view.window?.windowScene?.statusBarManager?.isStatusBarHidden ?? false,
    ]
  }

  /// Converts the trait edge to physical screen coordinates.
  static func edgeName(of traits: UITraitCollection?) -> String {
    guard #available(iOS 27.1, *), let traits else { return "none" }
    let rightToLeft = traits.layoutDirection == .rightToLeft
    switch traits.verticalBarEdge {
    case .leading:
      return rightToLeft ? "right" : "left"
    case .trailing:
      return rightToLeft ? "left" : "right"
    default:
      return "none"
    }
  }
}
