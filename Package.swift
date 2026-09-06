// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "multishell",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "MultishellCore", targets: ["MultishellCore"]),
    .library(name: "MultishellGitKit", targets: ["MultishellGitKit"]),
    .library(name: "MultishellAppCore", targets: ["MultishellAppCore"]),
    // The command-line helper that hooks and scripts call to report a
    // terminal's state. Ships inside the app bundle.
    .executable(name: "multishell", targets: ["MultishellCLI"]),
  ],
  targets: [
    // Pure model and state. No processes, no platform UI. The resources are
    // the shell-integration scripts, kept as shell files.
    .target(
      name: "MultishellCore",
      resources: [.copy("Resources/hooks.zsh"), .copy("Resources/init.bash")]),
    // Portable subprocess execution and Unix sockets.
    .target(name: "MultishellProcess"),
    // git worktree operations and their hooks.
    .target(name: "MultishellGitKit", dependencies: ["MultishellCore", "MultishellProcess"]),
    // The app layer: the model, detection, launch command lines, session
    // states, dialog texts, error presentation, the socket channel. A GUI
    // adds views and implements the ports.
    .target(
      name: "MultishellAppCore",
      dependencies: ["MultishellCore", "MultishellProcess", "MultishellGitKit"]),
    .executableTarget(
      name: "MultishellCLI", dependencies: ["MultishellCore", "MultishellProcess"]),

    .testTarget(name: "MultishellCoreTests", dependencies: ["MultishellCore"]),
    .testTarget(name: "MultishellProcessTests", dependencies: ["MultishellProcess"]),
    .testTarget(name: "MultishellGitKitTests", dependencies: ["MultishellGitKit"]),
    .testTarget(name: "MultishellAppCoreTests", dependencies: ["MultishellAppCore"]),
    // Runs the built helper against a real socket; depends on the target so
    // the binary exists before the test does.
    .testTarget(
      name: "MultishellCLITests",
      dependencies: ["MultishellCLI", "MultishellCore", "MultishellProcess"]),
  ]
)
