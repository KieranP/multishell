import Testing

@testable import MultishellAppCore
@testable import MultishellCore

/// Export's steps taken apart, so a poll or a second export can land between
/// them the way a slow volume lets either.
extension AppModelSharedSettingsExportTests {
  @Test func aPollReadingTheFileBeforeExportFinishesAsksNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(postCreateHook: "npm ci"), for: harness.project)
    harness.model.select(harness.model.workspace.worktrees(of: harness.project.id)[0])
    let export = try #require(try harness.model.prepareSharedSettingsExport(for: harness.project))

    let written = export.write()
    await harness.model.refreshSharedSettingsIfChanged(harness.project)
    harness.model.finishSharedSettingsExport(export, written)

    #expect(harness.model.pendingSharedSettingsTrust == nil, "the hook is the user's own")
    #expect(harness.model.trustsSharedSettings(of: harness.project))
  }

  @Test func anExportWrittenLateNeverLandsOverOneAskedAfterIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (first, second) = try exportTwice(harness)

    harness.model.finishSharedSettingsExport(second, second.write())
    harness.model.finishSharedSettingsExport(first, first.write())

    try expectSecondInForce(harness)
  }

  @Test func anExportFinishingLateLeavesTheLaterOneRecorded() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (first, second) = try exportTwice(harness)

    let firstWritten = first.write()
    harness.model.finishSharedSettingsExport(second, second.write())
    harness.model.finishSharedSettingsExport(first, firstWritten)

    try expectSecondInForce(harness)
  }

  private func exportTwice(
    _ harness: GitHarness
  ) throws -> (SharedSettingsExport, SharedSettingsExport) {
    harness.model.setSettings(ProjectSettings(postCreateHook: "npm ci"), for: harness.project)
    let first = try #require(try harness.model.prepareSharedSettingsExport(for: harness.project))
    harness.model.setSettings(ProjectSettings(postCreateHook: "make setup"), for: harness.project)
    let second = try #require(try harness.model.prepareSharedSettingsExport(for: harness.project))
    return (first, second)
  }

  private func expectSecondInForce(_ harness: GitHarness) throws {
    let onDisk = try #require(try SharedProjectSettings.load(from: harness.project.path))
    #expect(onDisk.postCreateHook == "make setup")
    let read = harness.project.sharedSettingsSnapshot
    #expect(read.asWritten == onDisk)
    let stamp = SharedSettingsReading.modificationDate(
      of: SharedProjectSettings.file(in: harness.project.path))
    #expect(!read.needsRead(at: stamp), "a stamp from the other write would hide the file")
    #expect(harness.model.trustsSharedSettings(of: harness.project))
  }
}
