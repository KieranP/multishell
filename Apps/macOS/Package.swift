// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Multishell",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(path: "../.."),
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
      ]
    ),
    // Pure pieces of the app: error mapping, metrics, colour derivation.
    // Views themselves stay untested here.
    .testTarget(name: "MultishellTests", dependencies: ["Multishell"]),
  ]
)
