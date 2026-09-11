// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "multishell",
  defaultLocalization: "en",
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
    // the shell-integration scripts, kept as shell files, and the libraries'
    // string catalogue, read through `t(_:_:)`. Inside the target that
    // declares them, so a path here is where it says it is; each frontend
    // keeps its own the same way. A new language is another `<code>.lproj`
    // beside `en.lproj` and another line here.
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
    // The app layer: the model, detection, launch command lines, session
    // states, dialog texts, error presentation, the socket channel. A GUI
    // adds views and implements the ports.
    .target(
      name: "MultishellAppCore",
      dependencies: ["MultishellCore", "MultishellProcess", "MultishellGitKit"]),
    .executableTarget(
      name: "MultishellCLI", dependencies: ["MultishellCore", "MultishellProcess"]),

    // What the test targets share. Plain targets, since a test target cannot
    // be depended on. Two of them: every suite wants a scratch directory,
    // but only the two that touch git want the git fixtures, and a Core or
    // Process suite should not link MultishellGitKit to get a temp path.
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
      dependencies: ["MultishellCLI", "MultishellCore", "MultishellProcess"]),
  ]
)
