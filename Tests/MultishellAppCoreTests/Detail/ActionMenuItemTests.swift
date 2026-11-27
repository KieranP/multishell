import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct ActionMenuItemTests {
  private func item(_ state: ActionRunState) -> ActionMenuItem {
    ActionMenuItem(name: "Serve", state: state, keys: nil)
  }

  @Test func aRowMarksARunWorkingAndItsEndDoneOrFailedAndShowsNothingIdle() {
    #expect(item(.running(since: Date())).markedState == .running)
    #expect(item(.done).markedState == .done)
    #expect(item(.failed).markedState == .failed)
    #expect(item(.idle).markedState == nil)
  }
}
