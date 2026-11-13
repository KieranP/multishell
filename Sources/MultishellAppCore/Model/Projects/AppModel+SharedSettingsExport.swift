import Foundation
import MultishellCore

extension AppModel {
  /// Export from the General tab. A refused hook or path list the file held
  /// is kept, and stays refused.
  public func exportSharedSettings(for project: Project) async {
    guard await rereadSharedSettingsBeforeExport(of: project) else { return }
    let export: SharedSettingsExport
    do {
      guard let prepared = try prepareSharedSettingsExport(for: project) else { return }
      export = prepared
    } catch {
      present(error)
      return
    }
    // The write, its date and the confinement off the main actor: on a slow
    // volume each would hold the window.
    let outcome = await runOnDispatch { export.write() }
    finishSharedSettingsExport(export, outcome)
  }

  /// The file as it is now, not as last read: a pull or an edit since would be
  /// written over. False where it will not parse, which says why.
  private func rereadSharedSettingsBeforeExport(of project: Project) async -> Bool {
    let serial = sharedSettingsReads.begin()
    let reading = await runOnDispatch { SharedSettingsReading.read(from: project) }
    guard workspace.project(project.id) != nil else { return false }
    if sharedSettingsReads.lands(serial, for: project.id) {
      applySharedSettingsReading(reading, for: project)
    }
    if case .failure(let error) = reading.loaded {
      present(
        UnreadableSharedSettingsFile(
          file: SharedProjectSettings.file(in: project.path),
          underlying: error,
        )
      )
      return false
    }
    return true
  }

  /// `nil` for a project gone from the workspace between the click and here,
  /// rather than writing a file into a project the user removed.
  func prepareSharedSettingsExport(for project: Project) throws -> SharedSettingsExport? {
    guard let project = workspace.project(project.id) else { return nil }
    // Over the file as written, not as confined: a path list a teammate wrote
    // goes back whole, the entries this checkout refuses included.
    let asWritten = project.sharedSettingsSnapshot.asWritten
    let mine = SharedProjectSettings(exporting: project.settings.layered(over: asWritten))
    let kept = mine.carryingOver(from: asWritten)
    // Every word the user's own answers itself; otherwise the answer given
    // about the file this rewrites travels, and no answer leaves the question.
    let answer =
      kept.trustCoveredText == mine.trustCoveredText
      ? true
      : project.sharedSettingsSnapshot.confined.flatMap { confined in
        project.settings.trustDecision(about: confined)
      }
    let (data, written) = try kept.fileContents()
    // Stored before the bytes can be read: a poll reading them first would
    // otherwise ask the user to trust what they just exported.
    if written.asksForTrust, let digest = written.digest, let answer {
      recordTrustDecision(digest: digest, isTrusted: answer, for: project.id)
    }
    let order = sharedSettingsExportOrders[project.id] ?? SaveOrder()
    sharedSettingsExportOrders[project.id] = order
    return SharedSettingsExport(
      project: project,
      contents: data,
      written: written,
      order: order,
      ticket: order.issue(),
    )
  }

  func finishSharedSettingsExport(
    _ export: SharedSettingsExport,
    _ outcome: Result<SharedSettingsReading?, any Error>,
  ) {
    let project = export.project
    guard workspace.project(project.id) != nil else { return }
    switch outcome {
    case .failure(let error):
      present(error)

    case .success(let reading?) where export.order.isLastLanded(export.ticket):
      // Numbered as it lands, its bytes being the newest: a poll's read begun
      // before the write and landing after would put the old file back.
      _ = sharedSettingsReads.lands(sharedSettingsReads.begin(), for: project.id)
      applySharedSettingsReading(reading, for: project)

    case .success:
      break
    }
  }
}
