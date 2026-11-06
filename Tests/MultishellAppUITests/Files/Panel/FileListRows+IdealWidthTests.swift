import AppKit
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore
@testable import MultishellGitKit

@Suite @MainActor
struct FileListRowsIdealWidthTests {
  @Test func theFitHoldsTheLongestFileNameWhole() {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree()
    let name = "zz-" + String(repeating: "a-long-file-name-", count: 10) + ".swift"
    let paths = (0..<15_000).map { "file\($0).txt" } + [name]
    harness.model.trackedFiles[worktree.id] = TrackedFiles(
      paths: paths,
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )
    let font = NSFont.systemFont(ofSize: harness.model.metrics.secondary)
    let nameWidth = (name as NSString).size(withAttributes: [.font: font]).width

    let width = FileListRows.idealWidth(of: worktree.id, in: harness.model)

    let insets = 2 * UIMetrics.filesPanelListSideInset
    #expect(width > nameWidth + insets, "\(width) for a \(nameWidth) pt name")
  }
}
