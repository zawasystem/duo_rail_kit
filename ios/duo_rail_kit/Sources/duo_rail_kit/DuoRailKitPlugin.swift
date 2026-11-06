import Flutter
import UIKit

/// Bridges Flutter custom rails to `UITraitCollection.verticalBarEdge` and the system bar layout
/// regions (iOS 27.1+).
///
/// Answers `getEdge`, and sends `edgeChanged` when a trait change or a move of the top bar layout
/// guide changes the payload; the README's native channel table lists the payload keys and when
/// each is present. Observation starts on `getEdge`, because the Flutter view controller may not
/// exist at registration. Every reply and event keeps these invariants:
/// - `edge` and the regions use physical left/right: leading/trailing is converted with the layout
///   direction of the same trait collection.
/// - Region values are points in the Flutter view's coordinates. All of them except `viewWidth`
///   and `viewHeight` (the view's size) are rounded to physical pixels.
/// - Every reply and event carries a new `sequence`, one more than the last one sent. Dart applies
///   only newer values, because replies and events can arrive out of order.
/// - `statusBarHidden` comes from the window scene (false without one) and is sampled with each
///   payload, not observed. `statusBarFrame` does not describe the status display's extent, so it
///   cannot replace the flag.
public final class DuoRailKitPlugin: NSObject, FlutterPlugin {
  /// Must match Dart's `VerticalBarEdge.channel`.
  private static let channelName = "com.zawasystem.fleet/vertical_bar_edge"

  /// Bar thickness requested from UIKit for both regions; it matches UIKit's default bar extent
  /// and navigation-bar button row on iPhone Duo.
  fileprivate static let barExtent: CGFloat = 48

  private let channel: FlutterMethodChannel
  private let registrar: FlutterPluginRegistrar

  /// Reattach observation when the Flutter view controller changes.
  private weak var observedViewController: UIViewController?

  /// The probe following the observed view's top bar layout guide; its superview owns it.
  private weak var regionProbe: BarRegionProbeView?

  /// Whether a probe-triggered refresh is already scheduled.
  private var regionRefreshScheduled = false

  /// The last payload sent in a reply or event, without its sequence number.
  private var lastValue: [String: AnyHashable]?

  /// The sequence number of the last reply or event.
  private var sequence = 0

  init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
    self.channel = channel
    self.registrar = registrar
    super.init()
  }

  /// Called by the generated plugin registration; the registrar retains the instance as its
  /// method-call delegate.
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
        // A reply always carries a new sequence number, even when the payload is unchanged.
        result(stamped(Self.value(of: viewController)))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Sending

  /// Sends `edgeChanged` unless the payload equals the last one sent.
  @MainActor
  private func send(_ value: [String: AnyHashable]) {
    // A relevant trait or layout change need not change the resulting payload.
    guard value != lastValue else { return }
    channel.invokeMethod("edgeChanged", arguments: stamped(value))
  }

  /// Records `value` as the last payload sent and returns it with the next sequence number.
  @MainActor
  private func stamped(_ value: [String: AnyHashable]) -> [String: AnyHashable] {
    lastValue = value
    sequence += 1
    var stamped = value
    stamped["sequence"] = sequence
    return stamped
  }

  // MARK: - Observation

  @MainActor
  private func observe(_ viewController: UIViewController?) {
    guard #available(iOS 27.1, *), let viewController else { return }
    // `value(of:)` may load the view after this call; attaching on every query is idempotent.
    attachRegionProbe(to: viewController.viewIfLoaded)
    guard viewController !== observedViewController else { return }
    observedViewController = viewController
    // UIKit ties observation to the view controller lifetime; no explicit cancellation token is needed.
    viewController.registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
      [weak self] (changed: UIViewController, _: UITraitCollection) in
      self?.send(Self.value(of: changed))
    }
  }

  /// Routes the probe of `view` to this plugin, installing it if the view has none.
  ///
  /// The previous view's probe stays installed with its callback cleared, so returning to that
  /// view reuses that probe and its guide.
  @available(iOS 27.1, *)
  @MainActor
  private func attachRegionProbe(to view: UIView?) {
    guard let view, view.traitCollection.userInterfaceIdiom == .phone else { return }
    if let probe = regionProbe, probe.superview === view { return }
    regionProbe?.onRegionChange = nil
    let probe = BarRegionProbeView.existing(in: view) ?? BarRegionProbeView.install(in: view)
    probe.onRegionChange = { [weak self] in self?.scheduleRegionRefresh() }
    regionProbe = probe
  }

  /// Recomputes the payload after the layout pass that moved the probe.
  ///
  /// Coalesces the probe's `center` and `bounds` updates; `send` drops unchanged payloads.
  @MainActor
  private func scheduleRegionRefresh() {
    guard !regionRefreshScheduled else { return }
    regionRefreshScheduled = true
    DispatchQueue.main.async { [weak self] in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.regionRefreshScheduled = false
        guard let viewController = self.observedViewController else { return }
        self.send(Self.value(of: viewController))
      }
    }
  }
}

// MARK: - Payload

extension DuoRailKitPlugin {
  /// The payload for `viewController`, without its sequence number.
  @MainActor
  private static func value(of viewController: UIViewController?) -> [String: AnyHashable] {
    let edge = edgeName(of: viewController?.traitCollection)
    // Reading `view`, unlike `viewIfLoaded`, loads the view.
    let view = viewController?.view
    var value: [String: AnyHashable] = [
      "edge": edge,
      "statusBarHidden": view?.window?.windowScene?.statusBarManager?.isStatusBarHidden ?? false,
    ]
    // The phone idiom excludes iPad and iPad apps running on a Mac.
    if #available(iOS 27.1, *), let view, view.traitCollection.userInterfaceIdiom == .phone {
      if let topBar = topBarRegion(in: view) {
        value["topBar"] = topBar
      }
      if let verticalBar = verticalBarRegion(in: view, edge: edge) {
        value["verticalBar"] = verticalBar
      }
    }
    return value
  }

  /// The trait's edge as a physical "left" or "right", or "none" when unavailable or unspecified.
  private static func edgeName(of traits: UITraitCollection?) -> String {
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

  /// The `topBar` entry, or nil unless the top bar region lies in the top safe area: non-empty,
  /// its top at least 0 and above the top safe-area inset, and its bottom at most 0.5 below the
  /// inset.
  ///
  /// That is the band beside the status display on the Duo inner portrait display. iPhone 17
  /// reports the region from the safe-area top, and Duo inner landscape has no top inset, so both
  /// return nil.
  @available(iOS 27.1, *)
  @MainActor
  private static func topBarRegion(in view: UIView) -> [String: Double]? {
    let scale = pixelScale(of: view)
    let safeTop = aligned(view.safeAreaInsets.top, scale)
    let region = UIView.LayoutRegion.bar(onEdge: UIRectEdge.top, extent: barExtent)
    guard let frame = rect(of: region, in: view, scale: scale),
      frame.minY >= 0, frame.minY < safeTop, frame.maxY <= safeTop + 0.5
    else { return nil }
    var result = fields(of: frame, in: view)
    result["safeTop"] = Double(safeTop)
    return result
  }

  /// The `verticalBar` entry, or nil unless `edge` is "left" or "right" and the vertical bar's
  /// item region on that edge is non-empty, starts at or after the view's top-left corner, and
  /// ends at most 0.5 past its right and bottom edges.
  ///
  /// Adds `topBarTop`, the top of the top bar region, when it is at least 0 and above the item
  /// region's bottom. Unlike `topBarRegion(in:)`, no safe-area condition applies: Duo inner
  /// landscape has no top inset but reports the top bar region at y 24.
  @available(iOS 27.1, *)
  @MainActor
  private static func verticalBarRegion(in view: UIView, edge: String) -> [String: Double]? {
    let side: UIRectEdge
    switch edge {
    case "left":
      side = UIRectEdge.left
    case "right":
      side = UIRectEdge.right
    default:
      return nil
    }
    let bounds = view.bounds
    let scale = pixelScale(of: view)
    let region = UIView.LayoutRegion.bar(onEdge: side, extent: barExtent)
    guard let frame = rect(of: region, in: view, scale: scale),
      frame.minX >= 0, frame.minY >= 0, frame.maxX <= bounds.width + 0.5, frame.maxY <= bounds.height + 0.5
    else { return nil }
    var result = fields(of: frame, in: view)
    if let row = rect(of: UIView.LayoutRegion.bar(onEdge: UIRectEdge.top, extent: barExtent), in: view, scale: scale),
      row.minY >= 0, row.minY < frame.maxY
    {
      result["topBarTop"] = Double(row.minY)
    }
    return result
  }

  /// The region's pixel-aligned rectangle in view coordinates, or nil when empty or non-finite.
  ///
  /// Uses `edgeInsets(for:)` rather than `layoutGuide(for:)`, which may add a guide per call.
  @available(iOS 27.1, *)
  @MainActor
  private static func rect(of region: UIView.LayoutRegion, in view: UIView, scale: CGFloat) -> CGRect? {
    // Read the raw size: CGRect's accessors standardise the negative size of oversized insets.
    let raw = view.bounds.inset(by: view.edgeInsets(for: region))
    let left = aligned(raw.origin.x, scale)
    let top = aligned(raw.origin.y, scale)
    let right = aligned(raw.origin.x + raw.size.width, scale)
    let bottom = aligned(raw.origin.y + raw.size.height, scale)
    guard [left, top, right, bottom].allSatisfy(\.isFinite), right > left, bottom > top else { return nil }
    return CGRect(x: left, y: top, width: right - left, height: bottom - top)
  }

  @MainActor
  private static func fields(of rect: CGRect, in view: UIView) -> [String: Double] {
    [
      "left": Double(rect.minX),
      "top": Double(rect.minY),
      "right": Double(rect.maxX),
      "bottom": Double(rect.maxY),
      "viewWidth": Double(view.bounds.width),
      "viewHeight": Double(view.bounds.height),
    ]
  }

  @MainActor
  private static func pixelScale(of view: UIView) -> CGFloat {
    let scale = view.traitCollection.displayScale
    return scale > 0 ? scale : 1
  }

  /// Rounds a coordinate in points to the nearest physical pixel.
  private static func aligned(_ value: CGFloat, _ scale: CGFloat) -> CGFloat {
    (value * scale).rounded() / scale
  }
}

// MARK: - Probe

/// A hidden, non-interactive view that follows its superview's top bar layout guide.
///
/// The guide also drives `verticalBar`'s `topBarTop`, so no other probe is needed for it.
/// UIKit may move the region without a trait or window-size change, for example if the status
/// display widens during a call, screen recording, or hotspot use. Any frame change triggers a
/// recomputed, deduplicated payload. One probe, and therefore one guide, is installed per view.
private final class BarRegionProbeView: UIView {
  /// Called on the main thread when UIKit moves or resizes the probe; must not retain the plugin.
  var onRegionChange: (@MainActor () -> Void)?

  // Auto Layout applies frames through `center` and `bounds`, not `frame`.
  override var bounds: CGRect {
    didSet {
      if bounds != oldValue { onRegionChange?() }
    }
  }

  override var center: CGPoint {
    didSet {
      if center != oldValue { onRegionChange?() }
    }
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

  static func existing(in view: UIView) -> BarRegionProbeView? {
    view.subviews.lazy.compactMap { $0 as? BarRegionProbeView }.first
  }

  @available(iOS 27.1, *)
  static func install(in view: UIView) -> BarRegionProbeView {
    let probe = BarRegionProbeView(frame: .zero)
    probe.isHidden = true
    probe.isUserInteractionEnabled = false
    probe.isAccessibilityElement = false
    probe.accessibilityElementsHidden = true
    probe.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(probe)
    // The only layoutGuide(for:) call for this view; repeated calls may add guides.
    let guide = view.layoutGuide(for: .bar(onEdge: UIRectEdge.top, extent: DuoRailKitPlugin.barExtent))
    NSLayoutConstraint.activate([
      probe.leftAnchor.constraint(equalTo: guide.leftAnchor),
      probe.rightAnchor.constraint(equalTo: guide.rightAnchor),
      probe.topAnchor.constraint(equalTo: guide.topAnchor),
      probe.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
    ])
    return probe
  }
}
