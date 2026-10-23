import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct FileTreeTests {
  private static let tracked = TrackedFiles(
    paths: [
      "README.md", "Sources/App/main.swift", "Sources/App/View.swift",
      "Tests/AppTests/Detail/A.swift",
      "vendor",
    ],
    submodulePaths: ["vendor"],
    notCheckedOutPaths: [],
    isCapped: false,
  )

  private static let changes = [
    StatusChange(
      path: "Tests/AppTests/Detail/A.swift",
      kind: .modified,
      lines: .counted(insertions: 4, deletions: 1),
    ),
    StatusChange(
      path: "new.txt",
      kind: .added,
      lines: .counted(insertions: 2, deletions: 0),
    ),
  ]

  private static var unopenableRow: FileTreeRow {
    let tracked = TrackedFiles(
      paths: ["gone.txt"],
      submodulePaths: [],
      notCheckedOutPaths: ["gone.txt"],
      isCapped: false,
    )
    return FileTree(FileTreeSources(tracked: tracked, status: nil)).rows(state: FilesPanelState())[
      0
    ]
  }

  private static func status(_ changes: [StatusChange], untracked: [String] = []) -> WorktreeStatus
  {
    var status = WorktreeStatus()
    status.untracked = untracked.count
    status.untrackedPaths = untracked
    status.changedFiles = changes.count
    status.setChanges(changes)
    return status
  }

  @Test func theChangedCountTakesEachPathOnceAndNoneOfAnOpenedSubmodules() {
    let removedButKept = StatusChange(
      path: "new.txt",
      kind: .deleted,
      lines: .counted(insertions: 0, deletions: 2),
    )
    let submoduleChange = StatusChange(
      path: "lib.c",
      kind: .modified,
      lines: .counted(insertions: 1, deletions: 0),
    )
    var sources = FileTreeSources(
      tracked: Self.tracked,
      status: Self.status(Self.changes + [removedButKept]),
    )
    sources.submodules["vendor"] = SubmoduleReading(
      tracked: .empty,
      status: Self.status([submoduleChange]),
    )

    #expect(FileTree(sources).changedFileCount == 2)
  }

  @Test func allListsFoldersFirstAndShutWithADotWhereTheyHoldAChange() {
    let tree = FileTree(
      FileTreeSources(
        tracked: Self.tracked,
        status: Self.status(Self.changes, untracked: ["new.txt"]),
      )
    )

    let rows = tree.rows(state: FilesPanelState())

    #expect(rows.map(\.name) == ["Sources", "Tests", "vendor", "new.txt", "README.md"])
    #expect(rows.map(\.holdsChange) == [false, true, false, false, false])
    #expect(rows.first { $0.name == "vendor" }?.isRepository == true)
    #expect(
      rows.first { $0.name == "new.txt" }?.lineCounts
        == FileLineCounts(insertions: 2, deletions: 0)
    )
  }

  @Test func anOpenedFolderShowsItsContentsOneLevelIn() {
    let tree = FileTree(FileTreeSources(tracked: Self.tracked, status: nil))
    var state = FilesPanelState()
    state.expandedFolders = ["Sources", "Sources/App"]

    let rows = tree.rows(state: state)

    #expect(rows.map(\.name).prefix(4) == ["Sources", "App", "main.swift", "View.swift"])
    #expect(rows.map(\.depth).prefix(4) == [0, 1, 2, 2])
  }

  @Test func modifiedListsOnlyChangesWithEachChainOfSingleChildFoldersMerged() {
    let tree = FileTree(
      FileTreeSources(
        tracked: Self.tracked,
        status: Self.status(Self.changes, untracked: ["new.txt"]),
      )
    )
    var state = FilesPanelState()
    state.mode = .modified

    #expect(tree.rows(state: state).map(\.name) == ["Tests/AppTests/Detail", "A.swift", "new.txt"])
    state.collapsedModifiedFolders = ["Tests/AppTests/Detail"]
    #expect(tree.rows(state: state).map(\.name) == ["Tests/AppTests/Detail", "new.txt"])
    #expect(tree.changedFileCount == 2)
  }

  @Test func aFilterListsEveryMatchingFileFlatWithItsFolder() {
    let tree = FileTree(FileTreeSources(tracked: Self.tracked, status: nil))
    var state = FilesPanelState()
    state.filterText = "VIEW"

    let rows = tree.rows(state: state)

    #expect(rows.map(\.name) == ["View.swift"])
    #expect(rows.first?.parentFolder == "Sources/App")
  }

  @Test func aDeletedFileTheIndexNoLongerHasIsStillListed() {
    let gone = StatusChange(
      path: "old.txt",
      kind: .deleted,
      lines: .counted(insertions: 0, deletions: 3),
    )

    let rows = FileTree(FileTreeSources(tracked: Self.tracked, status: Self.status([gone]))).rows(
      state: FilesPanelState()
    )

    #expect(rows.first { $0.name == "old.txt" }?.changeKind == .deleted)
  }

  @Test func aPathThatIsNotUTF8ListsButDoesNotOpen() {
    let tracked = TrackedFiles(
      paths: ["caf\u{FFFD}.txt", "plain.txt"],
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )

    let rows = FileTree(FileTreeSources(tracked: tracked, status: nil)).rows(
      state: FilesPanelState()
    )

    #expect(rows.map(\.isOpenable) == [false, true])
  }

  @Test func aNestedRepositoryListedWithItsSlashIsAFolder() {
    let tree = FileTree(
      FileTreeSources(tracked: .empty, status: Self.status([], untracked: ["nested/"]))
    )

    #expect(
      tree.rows(state: FilesPanelState()).map { [$0.name, "\($0.isRepository)"] } == [
        ["nested", "true"]
      ]
    )
  }

  @Test func whatGitIgnoresListsGreyedAndAnOpenedIgnoredFolderListsWhatIsOnDisk() {
    var sources = FileTreeSources(tracked: Self.tracked)
    sources.ignoredEntries = ["node_modules/", "debug.log"]
    sources.ignoredFolderEntries = [
      "node_modules": [IgnoredFolderEntry(name: "left-pad", isFolder: true)]
    ]
    var state = FilesPanelState()
    state.expandedFolders = ["node_modules"]

    let rows = FileTree(sources).rows(state: state)

    let ignored = rows.filter(\.isIgnored).map(\.path)
    #expect(ignored == ["node_modules", "node_modules/left-pad", "debug.log"])
    #expect(rows.first { $0.path == "node_modules/left-pad" }?.isFolder == true)
    #expect(rows.first { $0.path == "README.md" }?.isIgnored == false)
  }

  @Test func anIgnoredOrUnopenableNameIsFaintAnUnchangedFileQuietAndAChangeStrong() {
    var sources = FileTreeSources(tracked: Self.tracked, status: Self.status(Self.changes))
    sources.ignoredEntries = ["debug.log"]
    let rows = FileTree(sources).rows(state: FilesPanelState())
    let byName = Dictionary(rows.map { ($0.name, $0.emphasis) }, uniquingKeysWith: { a, _ in a })

    #expect(byName["debug.log"] == .faint)
    #expect(byName["README.md"] == .quiet)
    #expect(byName["new.txt"] == .strong)
    #expect(byName["Sources"] == .strong)
    #expect(Self.unopenableRow.emphasis == .faint)
  }

  @Test func onlyAShutFolderHoldingAChangeShowsTheChangeDot() {
    let tree = FileTree(FileTreeSources(tracked: Self.tracked, status: Self.status(Self.changes)))
    var expanded = FilesPanelState()
    expanded.expandedFolders = ["Tests"]

    let shut = tree.rows(state: FilesPanelState())
    let open = tree.rows(state: expanded)

    #expect(shut.filter(\.showsChangeDot).map(\.path) == ["Tests"])
    #expect(open.filter(\.showsChangeDot).map(\.path).contains("Tests") == false)
    #expect(shut.first { $0.path == "new.txt" }?.showsChangeDot == false)
  }

  @Test func aTreeOnTheLastChangesForTheSameChangedPathsShowsTheNewCounts() {
    let before = FileTree(
      FileTreeSources(tracked: Self.tracked, status: Self.status(Self.changes))
    )
    let moved = Self.changes.map { change in
      StatusChange(
        path: change.path,
        kind: change.kind,
        lines: .counted(insertions: 9, deletions: 9),
      )
    }
    let sources = FileTreeSources(tracked: Self.tracked, status: Self.status(moved))

    let after = FileTree(sources, listing: before.listing, changes: before.changes)

    var state = FilesPanelState()
    state.mode = .modified
    let rows = after.rows(state: state).filter { !$0.isFolder }
    #expect(rows.map(\.path) == ["new.txt", "Tests/AppTests/Detail/A.swift"].sorted())
    #expect(rows.allSatisfy { $0.lineCounts == FileLineCounts(insertions: 9, deletions: 9) })
  }
}
