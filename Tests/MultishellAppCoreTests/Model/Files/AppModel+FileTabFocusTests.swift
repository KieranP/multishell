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
}
