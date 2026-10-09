// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "multishell",
  defaultLocalization: "en",
  platforms: [.macOS(.v26)],
  products: [
    .executable(name: "Multishell", targets: ["MultishellAppUI"]),
    // The helper hooks call, bundled as `multishell`. Built under another name, or
    // it and `Multishell` share one products path on a case-insensitive disk.
    .executable(name: "multishell-helper", targets: ["MultishellCLI"]),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-subprocess", from: "1.0.0")
  ],
  targets: [
    // libghostty, built from the ThirdParty/ghostty submodule by
    // Scripts/build-ghostty.sh; the submodule's commit is the pin.
    .binaryTarget(name: "GhosttyKit", path: ".build/ghostty/GhosttyKit.xcframework"),
    // Docs/develop/layout.md says what each target holds. Core's resources are the
    // shell scripts and the libraries' catalogue; see Docs/design/translation.md.
    .target(
      name: "MultishellCore",
      resources: [
        .copy("Resources/zsh"), .copy("Resources/bash"),
        .process("Resources/en.lproj"),
      ],
    ),
    .target(
      name: "MultishellProcess",
      dependencies: [.product(name: "Subprocess", package: "swift-subprocess")],
    ),
    .target(name: "MultishellGitKit", dependencies: ["MultishellCore", "MultishellProcess"]),
    .target(
      name: "MultishellAppCore",
      dependencies: ["MultishellCore", "MultishellProcess", "MultishellGitKit"],
    ),
    .executableTarget(
      name: "MultishellCLI",
      dependencies: ["MultishellCore", "MultishellProcess"],
    ),
    // The Mac app: views, the engine host and the platform port. Its own words
    // and the agent marks; the bundling files in Resources/ SwiftPM never sees.
    .executableTarget(
      name: "MultishellAppUI",
      dependencies: [
        "MultishellCore", "MultishellProcess", "MultishellGitKit", "MultishellAppCore",
        "GhosttyKit",
      ],
      resources: [.process("Resources/en.lproj"), .process("Resources/Marks")],
      // libghostty's own link needs, which its static archive cannot declare.
      linkerSettings: [.linkedLibrary("c++"), .linkedFramework("Carbon")],
    ),

    // What the suites share, split by what each drags in; see
    // Docs/develop/layout.md.
    .target(
      name: "TestScratch",
      dependencies: [
        "MultishellProcess", .product(name: "Subprocess", package: "swift-subprocess"),
      ],
      path: "Tests/TestScratch",
    ),
    .target(
      name: "TestSupport",
      dependencies: ["MultishellGitKit", "TestScratch"],
      path: "Tests/TestSupport",
    ),

    .testTarget(
      name: "MultishellCoreTests",
      dependencies: ["MultishellCore", "TestScratch"],
    ),
    .testTarget(
      name: "MultishellProcessTests",
      dependencies: ["MultishellProcess", "TestScratch"],
    ),
    .testTarget(
      name: "MultishellGitKitTests",
      dependencies: ["MultishellGitKit", "TestSupport", "TestScratch"],
    ),
    .testTarget(
      name: "MultishellAppCoreTests",
      dependencies: ["MultishellAppCore", "TestSupport", "TestScratch"],
      resources: [.copy("Fixtures")],
    ),
    // Runs the built helper against a real socket; depends on the target so
    // the binary exists before the test does.
    .testTarget(
      name: "MultishellCLITests",
      dependencies: ["MultishellCLI", "MultishellCore", "MultishellProcess", "TestScratch"],
    ),
    // The app's own values, its AppKit pieces, and views laid out in a window
    // never shown; see Docs/develop/tests.md.
    .testTarget(name: "MultishellAppUITests", dependencies: ["MultishellAppUI", "TestScratch"]),
  ],
)

// Stricter than Swift 6's defaults; Docs/develop/build.md says what each catches
// and why StrictMemorySafety is not among them.
for target in package.targets where target.type != .binary {
  target.swiftSettings =
    (target.swiftSettings ?? []) + [
      .enableUpcomingFeature("MemberImportVisibility"),
      .enableUpcomingFeature("ExistentialAny"),
      .treatAllWarnings(as: .error),
    ]
}
