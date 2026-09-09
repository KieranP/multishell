import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// Every runtime cache the model keeps about a project or a worktree is keyed
/// by its path, so a project that leaves must take its own path and its
/// worktrees' with it. Walked by reflection rather than field by field: a
/// cache added later is populated by the same refresh and caught here without
/// anyone remembering to extend this test.
@Suite(.serialized) @MainActor
struct ProjectRemovalTraceTests {
  /// Fields that are meant to still name a departed project, each for a
  /// reason the field's own comment gives.
  private static let exempt: Set<String> = [
    // Documented never to shrink while the app runs. A re-added project has
    // no saved sessions left for a stale entry to warm.
    "warmWorktrees",
    // Pruned by the next `refreshStatuses` against the workspace, which is
    // cheaper than walking every worktree on a removal.
    "_statuses",
    // A coalesced refresh that finds its worktree gone and does nothing.
    "pendingStatusRefreshes",
  ]

  @Test func removingAProjectLeavesNoRuntimeTraceOfIt() async throws {
    let h = try await GitHarness()
    let project = h.project

    // Give the repository a `.multishell.json` and a second worktree, so the
    // shared-settings cache, the merge scan and the record check all have
    // something to hold before the project goes.
    try #"{"branchPrefix": "team/"}"#.write(
      to: SharedProjectSettings.file(in: project.path), atomically: true, encoding: .utf8)
    await h.model.createWorktree(
      branch: "second", basedOn: nil, createBranch: true, in: project)
    await h.model.refreshAll()
    let worktrees = h.model.workspace.worktrees(of: project.id)
    _ = h.model.select(worktrees[0])
    // The references a window and a row hold, which no refresh will come
    // back to clear once the project has left.
    h.model.beginRenaming(worktrees[0])
    h.model.settingsProjectID = project.id
    // The dialogs a second scene can leave standing over a removal.
    h.model.requestNewWorktree(in: project)
    h.model.requestRemoval(of: worktrees[1])

    let paths = Set(
      [project.id] + h.model.workspace.worktrees(of: project.id).map(\.id))
    #expect(paths.count >= 2, "the project and at least one worktree of its own")
    #expect(
      h.model.sharedSettings[project.id] != nil, "the file was read, so the cache holds something")

    h.model.removeProject(project)

    for (field, value) in Self.traces(in: h.model, of: paths) {
      #expect(Bool(false), "\(field) still names \(value) after its project was removed")
    }
  }

  /// Walks the model's stored properties, recursing through value types and
  /// collections but never into a class, and reports every place one of
  /// `paths` survives.
  private static func traces(
    in model: AppModel<FakeSurface>, of paths: Set<String>
  ) -> [(field: String, value: String)] {
    var found: [(field: String, value: String)] = []
    for child in Mirror(reflecting: model).children {
      guard let label = child.label, !exempt.contains(label) else { continue }
      for hit in strings(in: child.value) where paths.contains(hit) {
        found.append((label, hit))
      }
    }
    return found
  }

  /// Every string reachable from `value` by value-type structure: dictionary
  /// keys, set and array members, and the stored properties of a struct or
  /// enum. Classes are skipped, which keeps the store, the registry and the
  /// engine out of it; they answer to the workspace, not to this.
  /// The bound is only a stop against a value type that somehow nests
  /// without end; nothing here is close to it, and a cache buried deeper
  /// than this would go unchecked.
  private static func strings(in value: Any, depth: Int = 0) -> [String] {
    guard depth < 12 else { return [] }
    if let text = value as? String { return [text] }
    if let keyed = value as? [String: Any] {
      return Array(keyed.keys) + keyed.values.flatMap { strings(in: $0, depth: depth + 1) }
    }
    if let set = value as? Set<String> { return Array(set) }
    if let list = value as? [String] { return list }
    let mirror = Mirror(reflecting: value)
    switch mirror.displayStyle {
    case .struct, .enum, .optional, .tuple, .collection, .set, .dictionary:
      return mirror.children.flatMap { strings(in: $0.value, depth: depth + 1) }
    default:
      return []
    }
  }
}
