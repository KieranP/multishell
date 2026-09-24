// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "multishell",
  defaultLocalization: "en",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "MultishellCore", targets: ["MultishellCore"]),
    .library(name: "MultishellProcess", targets: ["MultishellProcess"]),
    .library(name: "MultishellGitKit", targets: ["MultishellGitKit"]),
    .library(name: "MultishellAppCore", targets: ["MultishellAppCore"]),
    // The command-line helper that hooks and scripts call to report a
    // terminal's state. Ships inside the app bundle.
    .executable(name: "multishell", targets: ["MultishellCLI"]),
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
    // Portable subprocess execution and Unix sockets.
    .target(name: "MultishellProcess"),
    // git worktree operations and their hooks.
    .target(name: "MultishellGitKit", dependencies: ["MultishellCore", "MultishellProcess"]),
    // The app layer; Docs/develop/layout.md says what it holds.
    .target(
      name: "MultishellAppCore",
      dependencies: ["MultishellCore", "MultishellProcess", "MultishellGitKit"]),
    .executableTarget(
      name: "MultishellCLI", dependencies: ["MultishellCore", "MultishellProcess"]),

    // What the suites share, split by what each drags in; see
    // Docs/develop/layout.md.
    .target(name: "TestScratch", path: "Tests/TestScratch"),
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
  ]
)
