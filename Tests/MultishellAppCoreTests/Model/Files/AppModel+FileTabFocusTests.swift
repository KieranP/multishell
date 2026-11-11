import Foundation
import MultishellCore
import MultishellGitKit
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct AppModelFileTabFocusTests {
  @Test func aFileTabShownByTheReconcileIsHandedTheKeyboard() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    let (tab, _) = try harness.openFileTab()

    #expect(harness.model.fileTabFocusRequest == tab.id)
  }

  @Test func aFileTabAnExitedShellBringsInFrontIsReadAndHandedTheKeyboard() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    _ = try await harness.rowsArrive(in: tab.id)
    harness.model.newShellTab()
    let shell = try #require(harness.model.workspace.activeTab(in: main.id))
    #expect(!harness.model.holdsContent(tab.id))
    harness.model.fileTabFocusRequest = nil

    harness.engine.delegate?.terminalHost(harness.engine, didExit: shell.focusedSessionID)

    #expect(harness.model.fileTabFocusRequest == tab.id)
    #expect(try await harness.rowsArrive(in: tab.id) != nil)
  }
}
