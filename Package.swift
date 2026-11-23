// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "patchbay",
  // Process taps need 14.2; the lock-free ring buffer's Atomic needs 15.
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "patchbay", targets: ["patchbay"]),
    // The engine on its own, for the macOS app (rex/patchbay) to depend on.
    .library(name: "PatchbayCore", targets: ["PatchbayCore"]),
  ],
  targets: [
    .target(name: "PatchbayCore"),
    .target(name: "PatchbayTUI", dependencies: ["PatchbayCore"]),
    .executableTarget(name: "patchbay", dependencies: ["PatchbayCore", "PatchbayTUI"]),
    .testTarget(name: "PatchbayCoreTests", dependencies: ["PatchbayCore"]),
    .testTarget(name: "PatchbayTUITests", dependencies: ["PatchbayTUI", "PatchbayCore"]),
  ]
)
