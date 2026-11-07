import UIKit
import XCTest
@testable import duo_rail_kit

final class RunnerTests: XCTestCase {
  @MainActor
  func testMovingOnlyASideGuideRequestsARegionRefresh() throws {
    guard #available(iOS 27.1, *) else { throw XCTSkip("Bar regions require iOS 27.1") }
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIViewController()
    window.isHidden = false
    defer { window.isHidden = true }

    for edge in [UIRectEdge.left, .right] {
      let view = UIView(frame: CGRect(x: 0, y: 0, width: 951, height: 669))
      window.rootViewController?.view.addSubview(view)
      defer { view.removeFromSuperview() }
      let side = UILayoutGuide()
      view.addLayoutGuide(side)
      let top = side.topAnchor.constraint(equalTo: view.topAnchor, constant: 124)
      NSLayoutConstraint.activate([
        top,
        side.widthAnchor.constraint(equalToConstant: 48),
        side.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -34),
        side.leftAnchor.constraint(equalTo: view.leftAnchor, constant: edge == .left ? 24 : 879),
      ])

      var refreshes = 0
      BarRegionProbeView.observe(in: view, guideForEdge: { view, requestedEdge in
        requestedEdge == edge ? side : view.layoutGuide(for: .bar(onEdge: requestedEdge, extent: 48))
      }) { refreshes += 1 }
      window.layoutIfNeeded()
      let probes = view.subviews.compactMap { $0 as? BarRegionProbeView }
      let sideProbe = try XCTUnwrap(probes.first { $0.edge == edge })
      let topProbe = try XCTUnwrap(probes.first { $0.edge == .top })
      let topFrame = topProbe.frame
      let windowSize = view.bounds.size
      XCTAssertEqual(sideProbe.frame.minY, 124)

      for newTop: CGFloat in [200, 124] {
        let before = refreshes
        top.constant = newTop
        window.layoutIfNeeded()
        XCTAssertEqual(view.bounds.size, windowSize)
        XCTAssertEqual(topProbe.frame, topFrame)
        XCTAssertEqual(sideProbe.frame.minY, newTop)
        XCTAssertGreaterThan(refreshes, before)
      }

      BarRegionProbeView.stopObserving(in: view)
      let afterStop = refreshes
      top.constant = 200
      window.layoutIfNeeded()
      XCTAssertEqual(sideProbe.frame.minY, 200)
      XCTAssertEqual(refreshes, afterStop)
    }
  }
}
