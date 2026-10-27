import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct QuickSwitcherFileMatchesTests {
  private static func tree(
    _ paths: [String],
    notCheckedOut: Set<String> = [],
    ignored: [String] = [],
  ) -> FileTree {
    FileTree(
      FileTreeSources(
        tracked: TrackedFiles(
          paths: paths,
          submodulePaths: [],
          notCheckedOutPaths: notCheckedOut,
          isCapped: false,
        ),
        ignoredEntries: ignored,
      )
    )
  }

  private static func paths(_ text: String, in tree: FileTree, limit: Int = 10) -> [String] {
    QuickSwitcherFileMatches.paths(QuickSwitcherQuery(text), in: tree, limit: limit)
  }

  @Test func aFileIsFoundByEveryWordInsideItsPath() {
    let tree = Self.tree(["Sources/App/Shortcuts.swift", "Sources/Sidebar/Row.swift", "README.md"])

    #expect(Self.paths("app short", in: tree) == ["Sources/App/Shortcuts.swift"])
    #expect(Self.paths("SIDEBAR", in: tree) == ["Sources/Sidebar/Row.swift"])
  }

  @Test func aWordInTheFileNameRanksAboveTheSameWordInAFolder() {
    let tree = Self.tree(["Sidebar/Row.swift", "Views/Sidebar.swift"])

    #expect(Self.paths("sidebar", in: tree) == ["Views/Sidebar.swift", "Sidebar/Row.swift"])
  }

  @Test func aNameStartingWithTheWordRanksAboveOneOnlyHoldingItHoweverDeep() {
    let tree = Self.tree([
      "arrow.swift", "Sources/MultishellAppUI/QuickSwitcher/Components/Rows/Row.swift",
    ])

    #expect(
      Self.paths("row", in: tree) == [
        "Sources/MultishellAppUI/QuickSwitcher/Components/Rows/Row.swift", "arrow.swift",
      ]
    )
  }

  @Test func aShorterPathBreaksATie() {
    let tree = Self.tree(["a/b/c/Theme.swift", "Theme.swift"])

    #expect(Self.paths("theme", in: tree) == ["Theme.swift", "a/b/c/Theme.swift"])
  }

  @Test func ignoredAndNotCheckedOutFilesAreLeftOut() {
    let tree = Self.tree(
      ["src/config.ts", "src/config-sparse.ts"],
      notCheckedOut: ["src/config-sparse.ts"],
      ignored: ["config.local.ts"],
    )

    #expect(Self.paths("config", in: tree) == ["src/config.ts"])
  }

  @Test func aGitignoredFolderOpenedInTheFilesPanelStillHasItsFilesLeftOut() {
    let tree = FileTree(
      FileTreeSources(
        tracked: TrackedFiles(
          paths: ["src/react-app.tsx"],
          submodulePaths: [],
          notCheckedOutPaths: [],
          isCapped: false,
        ),
        ignoredEntries: ["node_modules/"],
        ignoredFolderEntries: [
          "node_modules": [
            IgnoredFolderEntry(name: "react", isFolder: true),
            IgnoredFolderEntry(name: "react.js", isFolder: false),
          ]
        ],
      )
    )

    #expect(Self.paths("react", in: tree) == ["src/react-app.tsx"])
  }

  @Test func anOpenedSubmodulesFilesAreLeftOut() {
    let tree = FileTree(
      FileTreeSources(
        tracked: TrackedFiles(
          paths: ["vendor/lib", "src/lib.swift"],
          submodulePaths: ["vendor/lib"],
          notCheckedOutPaths: [],
          isCapped: false,
        ),
        submodules: [
          "vendor/lib": SubmoduleReading(
            tracked: TrackedFiles(
              paths: ["lib.c"],
              submodulePaths: [],
              notCheckedOutPaths: [],
              isCapped: false,
            ),
            status: nil,
          )
        ],
      )
    )

    #expect(Self.paths("lib", in: tree) == ["src/lib.swift"])
  }

  @Test func theNameIsBoldWhereAWordWasFoundInIt() {
    let query = QuickSwitcherQuery("app ts")

    #expect(QuickSwitcherFileMatches.nameOffsets(query, in: "Shortcuts.swift") == [7, 8])
  }

  @Test func noTextFindsNoFiles() {
    #expect(Self.paths("  ", in: Self.tree(["README.md"])) == [])
  }

  @Test func theListStopsAtTheLimit() {
    let tree = Self.tree((1...20).map { "file\($0).txt" })

    #expect(Self.paths("file", in: tree, limit: 5).count == 5)
  }
}
