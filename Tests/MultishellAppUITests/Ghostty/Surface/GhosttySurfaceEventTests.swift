import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttySurfaceEventTests {
  private func action(
    _ tag: ghostty_action_tag_e,
    _ payload: ghostty_action_u = .init(),
  )
    -> ghostty_action_s
  {
    ghostty_action_s(tag: tag, action: payload)
  }

  @Test func aTitleIsCopiedOutOfThePayload() {
    let event = "~/code".withCString { title in
      var payload = ghostty_action_u()
      payload.set_title = ghostty_action_set_title_s(title: title)
      return GhosttySurfaceEvent(action(GHOSTTY_ACTION_SET_TITLE, payload))
    }
    #expect(event == .retitled("~/code"))
  }

  @Test func aCommandsStatusIsKeptAndAMissingOneIsNil() {
    var payload = ghostty_action_u()
    payload.command_finished = ghostty_action_command_finished_s(exit_code: 2, duration: 0)
    #expect(
      GhosttySurfaceEvent(action(GHOSTTY_ACTION_COMMAND_FINISHED, payload))
        == .commandFinished(exitCode: 2)
    )
    payload.command_finished.exit_code = -1
    #expect(
      GhosttySurfaceEvent(action(GHOSTTY_ACTION_COMMAND_FINISHED, payload))
        == .commandFinished(exitCode: nil)
    )
  }

  @Test func aPointerShapeAProgramAsksForIsKept() {
    var payload = ghostty_action_u()
    payload.mouse_shape = GHOSTTY_MOUSE_SHAPE_TEXT
    #expect(
      GhosttySurfaceEvent(action(GHOSTTY_ACTION_MOUSE_SHAPE, payload))
        == .pointerShape(GHOSTTY_MOUSE_SHAPE_TEXT)
    )
  }

  @Test func hidingAndShowingThePointerAreEvents() {
    var payload = ghostty_action_u()
    payload.mouse_visibility = GHOSTTY_MOUSE_HIDDEN
    #expect(
      GhosttySurfaceEvent(action(GHOSTTY_ACTION_MOUSE_VISIBILITY, payload))
        == .pointerVisible(false)
    )
    payload.mouse_visibility = GHOSTTY_MOUSE_VISIBLE
    #expect(
      GhosttySurfaceEvent(action(GHOSTTY_ACTION_MOUSE_VISIBILITY, payload))
        == .pointerVisible(true)
    )
  }

  @Test func aTitleWithNoTextIsNoEvent() {
    var payload = ghostty_action_u()
    payload.set_title = ghostty_action_set_title_s(title: nil)
    #expect(GhosttySurfaceEvent(action(GHOSTTY_ACTION_SET_TITLE, payload)) == nil)
  }

  @Test func aPasswordPromptAsksForSecureInput() {
    var payload = ghostty_action_u()
    payload.secure_input = GHOSTTY_SECURE_INPUT_ON
    #expect(
      GhosttySurfaceEvent(action(GHOSTTY_ACTION_SECURE_INPUT, payload))
        == .secureInput(GHOSTTY_SECURE_INPUT_ON)
    )
  }

  @Test func aRungBellIsTheBellEvent() {
    #expect(GhosttySurfaceEvent(action(GHOSTTY_ACTION_RING_BELL)) == .bell)
  }

  @Test func anActionTheAppLeavesToLibghosttyIsNoEvent() {
    #expect(GhosttySurfaceEvent(action(GHOSTTY_ACTION_OPEN_URL)) == nil)
  }
}
