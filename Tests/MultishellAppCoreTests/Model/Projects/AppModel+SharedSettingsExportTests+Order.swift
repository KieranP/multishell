import MultishellCore
import Testing

@testable import MultishellAppCore

/// Export's steps taken apart, so a poll or a second export can land between
/// them the way a slow volume lets either.
extension AppModelSharedSettingsExportTests {
  @Test func aPollReadingTheFileBeforeExportFinishesAsksNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "npm ci"), for: h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let export = try #require(try h.model.prepareSharedSettingsExport(for: h.project))

    let written = export.write()
    await h.model.refreshSharedSettingsIfChanged(h.project)
    h.model.finishSharedSettingsExport(export, written)

    #expect(h.model.pendingSharedSettingsTrust == nil, "the hook is the user's own")
    #expect(h.model.trustsSharedSettings(of: h.project))
  }

  @Test func anExportWrittenLateNeverLandsOverOneAskedAfterIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let (first, second) = try exportTwice(h)

    h.model.finishSharedSettingsExport(second, second.write())
    h.model.finishSharedSettingsExport(first, first.write())

    try expectSecondInForce(h)
  }

  @Test func anExportFinishingLateLeavesTheLaterOneRecorded() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let (first, second) = try exportTwice(h)

    let firstWritten = first.write()
    h.model.finishSharedSettingsExport(second, second.write())
    h.model.finishSharedSettingsExport(first, firstWritten)

    try expectSecondInForce(h)
  }

  private func exportTwice(
    _ h: GitHarness
  ) throws -> (SharedSettingsExport, SharedSettingsExport) {
    h.model.updateSettings(ProjectSettings(postCreateHook: "npm ci"), for: h.project)
    let first = try #require(try h.model.prepareSharedSettingsExport(for: h.project))
    h.model.updateSettings(ProjectSettings(postCreateHook: "make setup"), for: h.project)
    let second = try #require(try h.model.prepareSharedSettingsExport(for: h.project))
    return (first, second)
  }

  private func expectSecondInForce(_ h: GitHarness) throws {
    let onDisk = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(onDisk.postCreateHook == "make setup")
    let read = h.project.sharedSettings
    #expect(read.asWritten == onDisk)
    let stamp = SharedSettingsReading.modificationDate(
      of: SharedProjectSettings.file(in: h.project.path))
    #expect(!read.needsRead(at: stamp), "a stamp from the other write would hide the file")
    #expect(h.model.trustsSharedSettings(of: h.project))
  }
}
