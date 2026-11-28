import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelActionKeysRecordingTests {
  private let controlOptionS = KeyCombination(.character("s"), [.control, .option])

  @Test func allowedKeysAreSetAndEndTheRecording() {
    let harness = Harness.withServeAction()
    harness.model.startRecordingActionKeys(
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )
    #expect(
      harness.model.actionKeysRecording(forAction: ProjectAction.serve.name, in: harness.project)
        != nil
    )

    harness.model.submitRecordedActionKeys(
      controlOptionS,
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )

    #expect(
      harness.model.actionKeysRecording(forAction: ProjectAction.serve.name, in: harness.project)
        == nil
    )
    #expect(
      harness.model.ownSettings(of: harness.project).actionShortcuts.keys(
        for: ProjectAction.serve.name
      )
        == controlOptionS
    )
  }

  @Test func keysAMenuCommandHoldsKeepTheRecordingGoingAndNameTheHolder() {
    let harness = Harness.withServeAction()
    harness.model.startRecordingActionKeys(
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )

    harness.model.submitRecordedActionKeys(
      .command("t"),
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )

    let recording = harness.model.actionKeysRecording(
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )
    #expect(recording?.refusal == .heldBy(.command("t"), .newTab))
  }

  @Test func clearingAfterARefusalEndsTheRecordingAndItsRefusal() {
    let harness = Harness.withServeAction()
    harness.model.setActionKeys(
      controlOptionS,
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )
    harness.model.startRecordingActionKeys(
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )
    harness.model.submitRecordedActionKeys(
      .command("t"),
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )

    harness.model.clearRecordedActionKeys(forAction: ProjectAction.serve.name, in: harness.project)

    #expect(
      harness.model.actionKeysRecording(forAction: ProjectAction.serve.name, in: harness.project)
        == nil
    )
    #expect(
      harness.model.ownSettings(of: harness.project).actionShortcuts.keys(
        for: ProjectAction.serve.name
      ) == nil
    )
  }

  @Test func aRefusalIsNotedWhileRecordingAndThePanesWarningOnlyOnceRecordingEnds() {
    let harness = Harness.withServeAction()
    let model = harness.model
    model.setActionKeys(controlOptionS, forAction: ProjectAction.serve.name, in: harness.project)
    let warning = model.actionKeysNote(forAction: ProjectAction.serve.name, in: harness.project)

    model.startRecordingActionKeys(forAction: ProjectAction.serve.name, in: harness.project)
    let whileRecording = model.actionKeysNote(
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )
    model.submitRecordedActionKeys(
      .command("t"),
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )
    let refusal = model.actionKeysNote(forAction: ProjectAction.serve.name, in: harness.project)
    model.endActionKeysRecording()

    #expect(warning == .warning(ShortcutWarning(keys: controlOptionS, shellUse: nil)))
    #expect(whileRecording == nil)
    #expect(refusal == .refusal(.heldBy(.command("t"), .newTab)))
    #expect(
      model.actionKeysNote(forAction: ProjectAction.serve.name, in: harness.project) == warning
    )
  }

  @Test func keysAMenuCommandIsLaterGivenNameThatCommandUnderTheAction() {
    let harness = Harness.withServeAction()
    let model = harness.model
    model.setActionKeys(controlOptionS, forAction: ProjectAction.serve.name, in: harness.project)

    model.setShortcut(controlOptionS, for: .newTab)

    #expect(
      model.actionKeysNote(forAction: ProjectAction.serve.name, in: harness.project)
        == .refusal(.heldBy(controlOptionS, .newTab))
    )
  }

  @Test func onlyTheRowBeingRecordedShowsTheRecording() {
    let harness = Harness.withServeAction()

    harness.model.startRecordingActionKeys(
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )

    #expect(harness.model.actionKeysRecording(forAction: "Deploy", in: harness.project) == nil)
    harness.model.endActionKeysRecording()
    #expect(
      harness.model.actionKeysRecording(forAction: ProjectAction.serve.name, in: harness.project)
        == nil
    )
  }

  @Test func aRecordingEndsWhenItsRowIsRenamedOrRemoved() {
    let harness = Harness.withServeAction()
    harness.model.startRecordingActionKeys(
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )

    harness.model.setActionName("Start", at: 0, in: harness.project)
    harness.model.setActionName(ProjectAction.serve.name, at: 0, in: harness.project)
    #expect(
      harness.model.actionKeysRecording(forAction: ProjectAction.serve.name, in: harness.project)
        == nil
    )

    harness.model.startRecordingActionKeys(
      forAction: ProjectAction.serve.name,
      in: harness.project,
    )
    harness.model.removeAction(at: 0, from: harness.project)
    #expect(
      harness.model.actionKeysRecording(forAction: ProjectAction.serve.name, in: harness.project)
        == nil
    )
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

  @Test func aFileRowLeavesItsKeysToAnOwnRowOfItsNameEvenUnfilled() async throws {
    let harness = Harness()
    try #"{ "actions": [ { "name": "Serve", "command": "npm start" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    #expect(harness.model.fileRowShowsKeys(forFileAction: "Serve", in: harness.project))

    harness.model.addAction(to: harness.project)
    harness.model.setActionName("Serve", at: 0, in: harness.project)

    #expect(!harness.model.fileRowShowsKeys(forFileAction: "Serve", in: harness.project))
  }
}
