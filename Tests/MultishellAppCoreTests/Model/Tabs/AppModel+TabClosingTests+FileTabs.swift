import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelTabClosingTests {
  @Test(arguments: [false, true])
  func closePaneAndCloseTabEachCloseAFileTabWhole(closesTheTab: Bool) {
    let harness = Harness()
    let file = harness.openFileTab()

    if closesTheTab { harness.model.closeActiveTab() } else { harness.model.closeActivePane() }

    #expect(harness.model.workspace.fileTab(file.id) == nil)
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == 1, "the shell stays")
    #expect(
      harness.model.pendingClose == nil,
      "one with no review comment being written asks nothing",
    )
  }

  @Test func closingAFileTabWhoseReviewCommentIsBeingWrittenAsksFirst() throws {
    let harness = Harness()
    let file = harness.openFileTab()
    let rows = FileTabRows.replacedBlock(before: 2, removed: 1, added: 2, after: 1)
    harness.model.fileTabReadings[file.id] = FileTabReading(
      content: .text(rows),
      isFileGone: false,
    )
    let selection = try #require(ReviewLineSelection(from: 0, to: 0, in: rows.lines))
    harness.model.openReviewComposer(on: selection, ofFile: file.path, in: file.id)
    harness.model.noteReviewDraft("Typed.", in: file.id)

    harness.model.closeTab(file.id)

    #expect(harness.model.workspace.fileTab(file.id) != nil, "the draft would go with it")
    let pending = try #require(harness.model.pendingClose)
    harness.model.answerClose(pending, confirmed: true)
    #expect(harness.model.workspace.fileTab(file.id) == nil)
  }

  @Test func aMiddleClickClosesAFileTabInTheBackground() {
    let harness = Harness()
    let file = harness.openFileTab()
    let shell = harness.model.workspace.tabs(in: harness.main.id)[0]
    harness.model.activateTab(shell.id)

    harness.model.closeTab(file.id)

    #expect(harness.model.workspace.fileTabs.isEmpty)
    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.id == shell.id)
  }
}
