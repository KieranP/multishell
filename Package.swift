// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "multishell",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "MultishellCore", targets: ["MultishellCore"]),
    .library(name: "MultishellGitKit", targets: ["MultishellGitKit"]),
    // The command-line helper that hooks and scripts call to report a
    // terminal's state. Ships inside the app bundle.
    .executable(name: "multishell", targets: ["MultishellCLI"]),
  ],
  targets: [
    // Pure model and state. No processes, no platform UI.
    .target(name: "MultishellCore"),
    // Portable subprocess execution and Unix sockets.
    .target(name: "MultishellProcess"),
    // git worktree operations and their hooks.
    .target(name: "MultishellGitKit", dependencies: ["MultishellCore", "MultishellProcess"]),
    .executableTarget(
      name: "MultishellCLI", dependencies: ["MultishellCore", "MultishellProcess"]),

    .testTarget(name: "MultishellCoreTests", dependencies: ["MultishellCore"]),
    .testTarget(name: "MultishellProcessTests", dependencies: ["MultishellProcess"]),
    .testTarget(name: "MultishellGitKitTests", dependencies: ["MultishellGitKit"]),
    // Runs the built helper against a real socket; depends on the target so
    // the binary exists before the test does.
    .testTarget(
      name: "MultishellCLITests",
      dependencies: ["MultishellCLI", "MultishellCore", "MultishellProcess"]),
  ]
)
