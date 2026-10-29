import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelServicesPopoverTests {
  @Test func anotherRowsPopoverClosingLeavesTheOpenOneUp() {
    let harness = Harness()
    harness.model.setShowsServicesPopover(true, of: harness.feature.id)

    harness.model.setShowsServicesPopover(false, of: harness.main.id)

    #expect(harness.model.servicesPopoverWorktreeID == harness.feature.id)
  }

  @Test func aClosingRowsOwnPopoverGoes() {
    let harness = Harness()
    harness.model.setShowsServicesPopover(true, of: harness.feature.id)

    harness.model.setShowsServicesPopover(false, of: harness.feature.id)

    #expect(harness.model.servicesPopoverWorktreeID == nil)
  }
}
