// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Multishell",
  defaultLocalization: "en",
  platforms: [.macOS(.v14)],
  dependencies: [
    // Named, not just pathed: in a git worktree the directory is the branch's
    // name; see Docs/develop/dependencies.md.
    .package(name: "multishell", path: "../.."),
    // Pinned exactly: libghostty's embedding API is not stable, so a
    // range would let an upgrade break the build without warning.
    .package(url: "https://github.com/Lakr233/libghostty-spm", exact: "1.6.20260922"),
  ],
  targets: [
    .executableTarget(
      name: "Multishell",
      dependencies: [
        .product(name: "MultishellCore", package: "multishell"),
        .product(name: "MultishellProcess", package: "multishell"),
        .product(name: "MultishellGitKit", package: "multishell"),
        .product(name: "MultishellAppCore", package: "multishell"),
        .product(name: "GhosttyTerminal", package: "libghostty-spm"),
      ],
      // This frontend's own words and marks. Not Apps/macOS/Resources, which
      // SwiftPM never sees; see Docs/develop/layout.md.
      resources: [.process("Resources/en.lproj"), .process("Resources/Marks")]
    ),
    // The app's own values, its AppKit pieces, and views laid out in a window
    // never shown; see Docs/develop/tests.md.
    .testTarget(name: "MultishellTests", dependencies: ["Multishell"]),
  ]
)
