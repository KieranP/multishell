// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "multishell",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "MultishellCore", targets: ["MultishellCore"]),
    .library(name: "MultishellGitKit", targets: ["MultishellGitKit"]),
  ],
  targets: [
    // Pure model and state. No processes, no platform UI.
    .target(name: "MultishellCore"),
    // Portable subprocess execution.
    .target(name: "MultishellProcess"),
    // git worktree operations and their hooks.
    .target(name: "MultishellGitKit", dependencies: ["MultishellCore", "MultishellProcess"]),

    .testTarget(name: "MultishellCoreTests", dependencies: ["MultishellCore"]),
    .testTarget(name: "MultishellProcessTests", dependencies: ["MultishellProcess"]),
    .testTarget(name: "MultishellGitKitTests", dependencies: ["MultishellGitKit"]),
  ]
)
