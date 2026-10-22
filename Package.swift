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
    // Highlighting; see Docs/develop/dependencies.md. The runtime is named as
    // well, its C types living in its own `TreeSitter` module.
    .package(url: "https://github.com/tree-sitter/swift-tree-sitter", exact: "0.25.0"),
    .package(url: "https://github.com/tree-sitter/tree-sitter", exact: "0.25.10"),
    // Each grammar at a tag that commits its generated parser; their queries ship
    // in each package's resource bundle. See Docs/develop/dependencies.md.
    .package(
      url: "https://github.com/alex-pinkus/tree-sitter-swift",
      exact: "0.7.4-with-generated-files",
    ),
    .package(url: "https://github.com/tree-sitter/tree-sitter-bash", exact: "0.25.1"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-c", exact: "0.24.2"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-c-sharp", exact: "0.23.5"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-cpp", exact: "0.23.4"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-css", exact: "0.25.0"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-go", exact: "0.25.0"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-html", exact: "0.23.2"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-java", exact: "0.23.5"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-javascript", exact: "0.25.0"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-json", exact: "0.24.8"),
    .package(url: "https://github.com/fwcd/tree-sitter-kotlin", exact: "0.3.8"),
    .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-make", exact: "1.1.1"),
    .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-markdown", exact: "0.5.3"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-php", exact: "0.25.1"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-python", exact: "0.25.0"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-ruby", exact: "0.23.1"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-rust", exact: "0.24.2"),
    // SQL commits its generated parser to `gh-pages` alone; see dependencies.md.
    .package(
      url: "https://github.com/DerekStride/tree-sitter-sql",
      revision: "39fdb006403747241244326e8af3b3e96b85381c",
    ),
    .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-scss", exact: "1.0.0"),
    .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-svelte", exact: "1.0.2"),
    .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-toml", exact: "0.7.0"),
    .package(url: "https://github.com/tree-sitter/tree-sitter-typescript", exact: "0.23.2"),
    .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-yaml", exact: "0.7.2"),
    .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-zig", exact: "1.1.2"),
  ],
  targets: [
    // libghostty, built from the ThirdParty/ghostty submodule by
    // Scripts/build-ghostty.sh; the submodule's commit is the pin.
    .binaryTarget(name: "GhosttyKit", path: ".build/ghostty/GhosttyKit.xcframework"),
    // Docs/develop/layout.md says what each target holds. Core's resources are the
    // shell scripts, the base themes and the libraries' catalogue (translation.md).
    .target(
      name: "MultishellCore",
      dependencies: ["MultishellProcess"],
      resources: [
        .copy("Resources/zsh"), .copy("Resources/bash"), .copy("Resources/fish"),
        .copy("Resources/themes"), .process("Resources/en.lproj"),
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
    // A file tab's highlighting, apart from the four libraries, which import
    // Apple's frameworks and swift-subprocess alone; see Docs/develop/layout.md.
    .target(
      name: "MultishellHighlight",
      dependencies: [
        "MultishellAppCore", "TreeSitterScanners",
        .product(name: "TreeSitterSwift", package: "tree-sitter-swift"),
        .product(name: "TreeSitterBash", package: "tree-sitter-bash"),
        .product(name: "TreeSitterC", package: "tree-sitter-c"),
        .product(name: "TreeSitterCPP", package: "tree-sitter-cpp"),
        .product(name: "TreeSitterCSharp", package: "tree-sitter-c-sharp"),
        .product(name: "TreeSitterCSS", package: "tree-sitter-css"),
        .product(name: "TreeSitterGo", package: "tree-sitter-go"),
        .product(name: "TreeSitterHTML", package: "tree-sitter-html"),
        .product(name: "TreeSitterJava", package: "tree-sitter-java"),
        .product(name: "TreeSitterJavaScript", package: "tree-sitter-javascript"),
        .product(name: "TreeSitterJSON", package: "tree-sitter-json"),
        .product(name: "TreeSitterKotlin", package: "tree-sitter-kotlin"),
        .product(name: "TreeSitterMake", package: "tree-sitter-make"),
        .product(name: "TreeSitterMarkdown", package: "tree-sitter-markdown"),
        .product(name: "TreeSitterPHP", package: "tree-sitter-php"),
        .product(name: "TreeSitterPython", package: "tree-sitter-python"),
        .product(name: "TreeSitterRuby", package: "tree-sitter-ruby"),
        .product(name: "TreeSitterRust", package: "tree-sitter-rust"),
        .product(name: "TreeSitterSCSS", package: "tree-sitter-scss"),
        .product(name: "TreeSitterSql", package: "tree-sitter-sql"),
        .product(name: "TreeSitterSvelte", package: "tree-sitter-svelte"),
        .product(name: "TreeSitterTOML", package: "tree-sitter-toml"),
        .product(name: "TreeSitterTypeScript", package: "tree-sitter-typescript"),
        .product(name: "TreeSitterYAML", package: "tree-sitter-yaml"),
        .product(name: "TreeSitterZig", package: "tree-sitter-zig"),
        .product(name: "SwiftTreeSitter", package: "swift-tree-sitter"),
        .product(name: "TreeSitter", package: "tree-sitter"),
      ],
    ),
    // The scanners CSS's, JavaScript's, Python's and YAML's packages leave out;
    // see Docs/develop/dependencies.md for why and for the warning.
    .target(
      name: "TreeSitterScanners",
      path: "ThirdParty/tree-sitter",
      sources: [
        "css/src/scanner.c", "javascript/src/scanner.c", "python/src/scanner.c",
        "yaml/src/scanner.c",
      ],
      cSettings: [.treatAllWarnings(as: .error), .disableWarning("shorten-64-to-32")],
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
        "MultishellHighlight", "GhosttyKit",
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
    .testTarget(
      name: "MultishellHighlightTests",
      dependencies: [
        "MultishellHighlight", "MultishellAppCore",
        .product(name: "SwiftTreeSitter", package: "swift-tree-sitter"),
      ],
    ),
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
