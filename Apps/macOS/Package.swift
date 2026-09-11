// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Multishell",
  defaultLocalization: "en",
  platforms: [.macOS(.v14)],
  dependencies: [
    // Named, not just pathed: SwiftPM takes a path dependency's identity from
    // its directory, which is "multishell" in a checkout but the branch's name
    // in a git worktree, and every `package: "multishell"` below would then
    // name a package that does not exist.
    .package(name: "multishell", path: "../.."),
    // Pinned exactly: libghostty's embedding API is not stable, so a
    // range would let an upgrade break the build without warning.
    .package(url: "https://github.com/Lakr233/libghostty-spm", exact: "1.5.20260906"),
    .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.20.0"),
  ],
  targets: [
    .executableTarget(
      name: "Multishell",
      dependencies: [
        .product(name: "MultishellCore", package: "multishell"),
        .product(name: "MultishellGitKit", package: "multishell"),
        .product(name: "MultishellAppCore", package: "multishell"),
        .product(name: "GhosttyTerminal", package: "libghostty-spm"),
        .product(name: "SwiftTerm", package: "SwiftTerm"),
      ],
      // This frontend's own words, inside the target that shows them. Not
      // `Apps/macOS/Resources`, which is the icon the bundling script
      // copies and nothing SwiftPM knows about. The libraries keep theirs
      // the same way, under MultishellCore.
      resources: [.process("Resources/en.lproj")]
    ),
    // Pure pieces of the app: error mapping, metrics, colour derivation.
    // Views themselves stay untested here.
    .testTarget(name: "MultishellTests", dependencies: ["Multishell"]),
  ]
)
