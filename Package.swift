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
    .package(url: "https://github.com/swiftlang/swift-subprocess", from: "1.0.0"),
    // Pinned exactly: libghostty's embedding API is not stable, so a
    // range would let an upgrade break the build without warning.
    .package(url: "https://github.com/Lakr233/libghostty-spm", exact: "1.6.20260922"),
  ],
  targets: [
    // Pure model and state. Its resources are the shell scripts and the
    // libraries' catalogue; see Docs/design/translation.md.
    .target(
      name: "MultishellCore",
      resources: [
        .copy("Resources/hooks.zsh"), .copy("Resources/init.bash"),
        .process("Resources/en.lproj"),
      ]),
    // Subprocess execution and Unix sockets.
    .target(
      name: "MultishellProcess",
      dependencies: [.product(name: "Subprocess", package: "swift-subprocess")]),
    // git worktree operations and their hooks.
    .target(name: "MultishellGitKit", dependencies: ["MultishellCore", "MultishellProcess"]),
    // The app layer; Docs/develop/layout.md says what it holds.
    .target(
      name: "MultishellAppCore",
      dependencies: ["MultishellCore", "MultishellProcess", "MultishellGitKit"]),
    .executableTarget(
      name: "MultishellCLI", dependencies: ["MultishellCore", "MultishellProcess"]),
    // The Mac app: views, the engine host and the platform port. Its own words
    // and the agent marks; the bundling files in Resources/ SwiftPM never sees.
    .executableTarget(
      name: "MultishellAppUI",
      dependencies: [
        "MultishellCore", "MultishellProcess", "MultishellGitKit", "MultishellAppCore",
        .product(name: "GhosttyTerminal", package: "libghostty-spm"),
      ],
      resources: [.process("Resources/en.lproj"), .process("Resources/Marks")]),

    // What the suites share, split by what each drags in; see
    // Docs/develop/layout.md.
    .target(
      name: "TestScratch",
      dependencies: [
        "MultishellProcess", .product(name: "Subprocess", package: "swift-subprocess"),
      ],
      path: "Tests/TestScratch"),
    .target(
      name: "TestSupport", dependencies: ["MultishellGitKit", "TestScratch"],
      path: "Tests/TestSupport"),

    .testTarget(
      name: "MultishellCoreTests", dependencies: ["MultishellCore", "TestScratch"]),
    .testTarget(
      name: "MultishellProcessTests", dependencies: ["MultishellProcess", "TestScratch"]),
    .testTarget(
      name: "MultishellGitKitTests",
      dependencies: ["MultishellGitKit", "TestSupport", "TestScratch"]),
    .testTarget(
      name: "MultishellAppCoreTests",
      dependencies: ["MultishellAppCore", "TestSupport", "TestScratch"]),
    // Runs the built helper against a real socket; depends on the target so
    // the binary exists before the test does.
    .testTarget(
      name: "MultishellCLITests",
      dependencies: ["MultishellCLI", "MultishellCore", "MultishellProcess", "TestScratch"]),
    // The app's own values, its AppKit pieces, and views laid out in a window
    // never shown; see Docs/develop/tests.md.
    .testTarget(name: "MultishellAppUITests", dependencies: ["MultishellAppUI"]),
  ]
)
