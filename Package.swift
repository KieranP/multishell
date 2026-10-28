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
    // Each grammar from GitHub's archive of its pinned commit, which
    // Scripts/fetch-grammars.sh fetches; why not git: dependencies.md.
    .package(path: ".build/grammars/tree-sitter-bash"),
    .package(path: ".build/grammars/tree-sitter-c"),
    .package(path: ".build/grammars/tree-sitter-c-sharp"),
    .package(path: ".build/grammars/tree-sitter-cpp"),
    .package(path: ".build/grammars/tree-sitter-css"),
    .package(path: ".build/grammars/tree-sitter-go"),
    .package(path: ".build/grammars/tree-sitter-html"),
    .package(path: ".build/grammars/tree-sitter-java"),
    .package(path: ".build/grammars/tree-sitter-javascript"),
    .package(path: ".build/grammars/tree-sitter-json"),
    .package(path: ".build/grammars/tree-sitter-kotlin"),
    .package(path: ".build/grammars/tree-sitter-make"),
    .package(path: ".build/grammars/tree-sitter-markdown"),
    .package(path: ".build/grammars/tree-sitter-php"),
    .package(path: ".build/grammars/tree-sitter-python"),
    .package(path: ".build/grammars/tree-sitter-ruby"),
    .package(path: ".build/grammars/tree-sitter-rust"),
    .package(path: ".build/grammars/tree-sitter-scss"),
    .package(path: ".build/grammars/tree-sitter-sql"),
    .package(path: ".build/grammars/tree-sitter-svelte"),
    .package(path: ".build/grammars/tree-sitter-swift"),
    .package(path: ".build/grammars/tree-sitter-toml"),
    .package(path: ".build/grammars/tree-sitter-typescript"),
    .package(path: ".build/grammars/tree-sitter-yaml"),
    .package(path: ".build/grammars/tree-sitter-zig"),
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
    // Pull request hosts and CI providers, read through their own tools.
    .target(
      name: "MultishellServices",
      dependencies: ["MultishellCore", "MultishellProcess", "MultishellGitKit"],
    ),
    .target(
      name: "MultishellAppCore",
      dependencies: [
        "MultishellCore", "MultishellProcess", "MultishellGitKit", "MultishellServices",
      ],
    ),
    // A file tab's highlighting, apart from the five libraries, which import
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
        "MultishellCore", "MultishellProcess", "MultishellGitKit", "MultishellServices",
        "MultishellAppCore", "MultishellHighlight", "GhosttyKit",
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
      name: "MultishellServicesTests",
      dependencies: ["MultishellServices", "MultishellGitKit", "MultishellProcess", "TestScratch"],
    ),
    .testTarget(
      name: "MultishellAppCoreTests",
      dependencies: ["MultishellAppCore", "MultishellServices", "TestSupport", "TestScratch"],
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
