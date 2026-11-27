import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelActionKeysRecordingTests {
  private let controlOptionS = KeyCombination(.character("s"), [.control, .option])

  private func harnessWithServe() -> Harness {
    let harness = Harness()
    harness.model.setSettings(
      ProjectSettings(actions: [ProjectAction(name: "Serve", command: "npm run dev")]),
      for: harness.project,
    )
    return harness
  }

  @Test func allowedKeysAreSetAndEndTheRecording() {
    let harness = harnessWithServe()
    harness.model.startRecordingActionKeys(forAction: "Serve", in: harness.project)
    #expect(harness.model.actionKeysRecording(forAction: "Serve", in: harness.project) != nil)

    harness.model.submitRecordedActionKeys(controlOptionS, forAction: "Serve", in: harness.project)

    #expect(harness.model.actionKeysRecording(forAction: "Serve", in: harness.project) == nil)
    #expect(
      harness.model.ownSettings(of: harness.project).actionShortcuts.keys(for: "Serve")
        == controlOptionS
    )
  }

  @Test func keysAMenuCommandHoldsKeepTheRecordingGoingAndNameTheHolder() {
    let harness = harnessWithServe()
    harness.model.startRecordingActionKeys(forAction: "Serve", in: harness.project)

    harness.model.submitRecordedActionKeys(.command("t"), forAction: "Serve", in: harness.project)

    let recording = harness.model.actionKeysRecording(forAction: "Serve", in: harness.project)
    #expect(recording?.refusal == .heldBy(.command("t"), .newTab))
  }

  @Test func clearingAfterARefusalEndsTheRecordingAndItsRefusal() {
    let harness = harnessWithServe()
    harness.model.setActionKeys(controlOptionS, forAction: "Serve", in: harness.project)
    harness.model.startRecordingActionKeys(forAction: "Serve", in: harness.project)
    harness.model.submitRecordedActionKeys(.command("t"), forAction: "Serve", in: harness.project)

    harness.model.clearRecordedActionKeys(forAction: "Serve", in: harness.project)

    #expect(harness.model.actionKeysRecording(forAction: "Serve", in: harness.project) == nil)
    #expect(
      harness.model.ownSettings(of: harness.project).actionShortcuts.keys(for: "Serve") == nil
    )
  }

  @Test func aRefusalIsNotedWhileRecordingAndThePanesWarningOnlyOnceRecordingEnds() {
    let harness = harnessWithServe()
    let model = harness.model
    model.setActionKeys(controlOptionS, forAction: "Serve", in: harness.project)
    let warning = model.actionKeysNote(forAction: "Serve", in: harness.project)

    model.startRecordingActionKeys(forAction: "Serve", in: harness.project)
    let whileRecording = model.actionKeysNote(forAction: "Serve", in: harness.project)
    model.submitRecordedActionKeys(.command("t"), forAction: "Serve", in: harness.project)
    let refusal = model.actionKeysNote(forAction: "Serve", in: harness.project)
    model.endActionKeysRecording()

    #expect(warning == .warning(ShortcutWarning(keys: controlOptionS, shellUse: nil)))
    #expect(whileRecording == nil)
    #expect(refusal == .refusal(.heldBy(.command("t"), .newTab)))
    #expect(model.actionKeysNote(forAction: "Serve", in: harness.project) == warning)
  }

  @Test func onlyTheRowBeingRecordedShowsTheRecording() {
    let harness = harnessWithServe()

    harness.model.startRecordingActionKeys(forAction: "Serve", in: harness.project)

    #expect(harness.model.actionKeysRecording(forAction: "Deploy", in: harness.project) == nil)
    harness.model.endActionKeysRecording()
    #expect(harness.model.actionKeysRecording(forAction: "Serve", in: harness.project) == nil)
  }

  @Test func aRecordingEndsWhenItsRowIsRenamedOrRemoved() {
    let harness = harnessWithServe()
    harness.model.startRecordingActionKeys(forAction: "Serve", in: harness.project)

    harness.model.setActionName("Start", at: 0, in: harness.project)
    harness.model.setActionName("Serve", at: 0, in: harness.project)
    #expect(harness.model.actionKeysRecording(forAction: "Serve", in: harness.project) == nil)

    harness.model.startRecordingActionKeys(forAction: "Serve", in: harness.project)
    harness.model.removeAction(at: 0, from: harness.project)
    #expect(harness.model.actionKeysRecording(forAction: "Serve", in: harness.project) == nil)
  }

  @Test func aRecordingEndsWhenTheFileDropsItsAction() async throws {
    let harness = Harness()
    let file = SharedProjectSettings.file(in: harness.root)
    try #"{ "actions": [ { "name": "Seed", "command": "bin/seed" } ] }"#.write(
      to: file,
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.startRecordingActionKeys(forAction: "Seed", in: harness.project)

    try "{}".write(to: file, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.modificationDate: Date(timeIntervalSinceNow: 60)],
      ofItemAtPath: file.path,
    )
    await harness.model.refreshSharedSettingsIfChanged()

    #expect(harness.model.actionKeysRecording(forAction: "Seed", in: harness.project) == nil)
  }
}
