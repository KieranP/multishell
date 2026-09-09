import Foundation
import MultishellCore

/// What each project's `.multishell.json` said when it was last read.
///
/// Three facts per project: what the file says, the date it had when it was
/// read, and why it would not parse. One entry rather than three dictionaries
/// so a project that leaves takes all three with it, and so a fourth fact can
/// be added without hunting for the places that clear the other three. Pure,
/// so the read rules are tested without a model or a disk.
///
/// The stamps ride along in the observed value, where they were once kept out
/// of it: a file rewritten with the same bytes now re-renders the views that
/// read the settings, having only moved a date. That costs a sidebar pass the
/// status poll makes every few seconds anyway, which is the cheaper side of
/// the trade against a stamp nobody clears when its project leaves.
public struct SharedSettingsCache: Equatable, Sendable {
  public struct Entry: Equatable, Sendable {
    /// Absent for a project whose repository has no file, and for one whose
    /// file would not parse.
    public var settings: SharedProjectSettings?
    /// The date the file had when it was read, `.distantPast` for one that
    /// is not there. A stat against this tells an edited file from an
    /// untouched one without a read.
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

  /// Whether this project's file has been read at all this run. A first read
  /// says nothing about hooks, so a launch with several projects does not
  /// open with a queue of questions about repositories nobody is looking at.
  public func hasRead(_ id: Project.ID) -> Bool {
    entries[id] != nil
  }

  /// A read that parsed. The stamp is recorded either way; the returned
  /// value says whether what the file says actually moved, which is what the
  /// hook question turns on.
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

  /// A read that failed, which costs the project its shared settings rather
  /// than the project itself. Returns whether the problem is a new one, so
  /// the same unparsable file is logged once rather than on every tick.
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
  /// so a repository that could not be read the first time is not still
  /// dimmed with no alert.
  public mutating func forget(_ id: Project.ID) {
    entries[id] = nil
  }
}
