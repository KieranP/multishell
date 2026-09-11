import Foundation
import MultishellCore

/// What each project's `.multishell.json` said when last read. One entry per
/// project, so one that leaves takes all three facts with it.
public struct SharedSettingsCache: Equatable, Sendable {
  public struct Entry: Equatable, Sendable {
    /// Absent for a project whose repository has no file, and for one whose
    /// file would not parse.
    public var settings: SharedProjectSettings?
    /// The date the file had when read, `.distantPast` for one not there. A
    /// stat against this tells an edited file without a read.
    public var stamp: Date
    /// Why it could not be read, for the project's Hooks tab.
    public var problem: String?
  }

  private var entries: [Project.ID: Entry] = [:]

  public init() {}

  public subscript(id: Project.ID) -> SharedProjectSettings? { entries[id]?.settings }

  public func problem(of id: Project.ID) -> String? { entries[id]?.problem }

  /// Whether the file's date has moved since it was read, which is what a
  /// tick asks before spending a read. True for a project never read.
  public func hasMoved(_ stamp: Date, for id: Project.ID) -> Bool {
    entries[id]?.stamp != stamp
  }

  /// Whether this project's file has been read at all this run: a first read
  /// says nothing about hooks, so a launch opens with no queue of questions.
  public func hasRead(_ id: Project.ID) -> Bool {
    entries[id] != nil
  }

  /// A read that parsed, the stamp recorded either way. The result says
  /// whether the contents moved, which the hook question turns on.
  @discardableResult
  public mutating func note(
    _ settings: SharedProjectSettings?, stamp: Date, for id: Project.ID
  ) -> Bool {
    var entry = entries[id] ?? Entry(settings: nil, stamp: stamp, problem: nil)
    let changed = entry.settings != settings
    entry.settings = settings
    entry.stamp = stamp
    entry.problem = nil
    entries[id] = entry
    return changed
  }

  /// A read that failed, costing the shared settings and not the project.
  /// Returns whether the problem is new, so it is logged once.
  @discardableResult
  public mutating func note(problem: String, stamp: Date, for id: Project.ID) -> Bool {
    var entry = entries[id] ?? Entry(settings: nil, stamp: stamp, problem: nil)
    let isNew = entry.problem != problem
    entry.settings = nil
    entry.stamp = stamp
    entry.problem = problem
    entries[id] = entry
    return isNew
  }

  /// The project has left the workspace. Re-adding it reads the file afresh,
  /// so an unreadable repository is not still dimmed with no alert.
  public mutating func forget(_ id: Project.ID) {
    entries[id] = nil
  }
}
