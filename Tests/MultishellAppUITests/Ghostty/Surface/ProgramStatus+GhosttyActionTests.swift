import GhosttyKit
import MultishellCore
import Testing

@testable import MultishellAppUI

@Suite
struct ProgramStatusGhosttyActionTests {
  @Test func aChildRecordIsCopiedOutWithItsAppReasonAndMessage() {
    let status = "remote/plan".withCString { id in
      "claude-code".withCString { app in
        "Approve the plan?".withCString { message in
          ProgramStatus(
            ghostty_action_program_status_s(
              state: GHOSTTY_PROGRAM_STATUS_BLOCKED,
              kind: GHOSTTY_PROGRAM_STATUS_KIND_PERMISSION,
              progress: -1,
              id: id,
              app: app,
              title: nil,
              msg: message,
            )
          )
        }
      }
    }
    #expect(
      status
        == ProgramStatus(
          state: .blocked,
          blockedReason: .permission,
          recordID: "remote/plan",
          app: "claude-code",
          message: "Approve the plan?",
        )
    )
  }

  @Test func theProgramsOwnRecordHasNoIDAndAnErrorIsAFailure() {
    let status = ProgramStatus(
      ghostty_action_program_status_s(
        state: GHOSTTY_PROGRAM_STATUS_ERROR,
        kind: GHOSTTY_PROGRAM_STATUS_KIND_NONE,
        progress: -1,
        id: nil,
        app: nil,
        title: nil,
        msg: nil,
      )
    )
    #expect(status == ProgramStatus(state: .failed))
  }

  @Test func aStateALaterLibghosttyAddsIsDropped() {
    let status = ProgramStatus(
      ghostty_action_program_status_s(
        state: ghostty_action_program_status_state_e(rawValue: 99),
        kind: GHOSTTY_PROGRAM_STATUS_KIND_NONE,
        progress: -1,
        id: nil,
        app: nil,
        title: nil,
        msg: nil,
      )
    )
    #expect(status == nil)
  }
}
