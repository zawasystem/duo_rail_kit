// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "duo_rail_kit",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(name: "duo-rail-kit", targets: ["duo_rail_kit"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "duo_rail_kit",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ]
    )
  ]
)
