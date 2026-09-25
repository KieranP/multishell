import Foundation
import MultishellCore

extension AppModel {
  /// Export from the General tab. A refused hook or path list the file held
  /// is kept, and stays refused.
  public func exportSharedSettings(for project: Project) async {
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
    let written = await offMain { Self.writeSharedSettings(export) }
    finishSharedSettingsExport(export, written)
  }

  /// `nil` for a project gone from the workspace between the click and here,
  /// rather than writing a file into a project the user removed.
  func prepareSharedSettingsExport(for project: Project) throws -> SharedSettingsExport? {
    guard let project = workspace.project(project.id) else { return nil }
    let mine = SharedProjectSettings(exporting: effectiveSettings(for: project))
    let kept = mine.keeping(from: project.sharedSettings.asWritten)
    // Every word the user's own answers itself; otherwise the answer given
    // about the file this rewrites travels, and no answer leaves the question.
    let answer =
      kept.trustCoveredText == mine.trustCoveredText
      ? true
      : project.sharedSettings.confined.flatMap {
        project.settings.trustDecision(about: $0)
      }
    let (data, written) = try kept.fileContents()
    // Stored before the bytes can be read: a poll reading them first would
    // otherwise ask the user to trust what they just exported.
    if written.asksForTrust, let digest = written.digest, let answer {
      recordTrustDecision(digest: digest, trusted: answer, for: project.id)
    }
    let order = sharedSettingsWrites[project.id] ?? SaveOrder()
    sharedSettingsWrites[project.id] = order
    return SharedSettingsExport(
      project: project, data: data, written: written, order: order, ticket: order.issue())
  }

  /// `nil` where a later export landed first, which leaves the file to it.
  nonisolated static func writeSharedSettings(
    _ export: SharedSettingsExport
  ) -> Result<SharedSettingsReading?, any Error> {
    let file = SharedProjectSettings.file(in: export.project.path)
    return Result {
      let stamp = try export.order.land(export.ticket) {
        try export.data.write(to: file, options: .atomic)
        return modificationDate(of: file)
      }
      return stamp.map {
        SharedSettingsReading(result: .success(export.written), stamp: $0, project: export.project)
      }
    }
  }

  func finishSharedSettingsExport(
    _ export: SharedSettingsExport, _ written: Result<SharedSettingsReading?, any Error>
  ) {
    let project = export.project
    guard workspace.project(project.id) != nil else { return }
    switch written {
    case .failure(let error):
      present(error)
    case .success(let reading?) where export.order.isLastLanded(export.ticket):
      applySharedSettingsReading(reading, for: project)
    case .success:
      break
    }
  }
}
