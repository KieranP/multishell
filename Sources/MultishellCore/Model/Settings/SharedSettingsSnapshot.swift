import Foundation

/// What a project's `.multishell.json` said when last read, and what it may
/// say here. Per run: `Project` leaves it out of coding and equality.
public struct SharedSettingsSnapshot: Equatable, Sendable {
  /// The file's own words. For export, which writes them back; every other
  /// reader wants `confined`.
  public var asWritten: SharedProjectSettings?
  /// The same with what the repository may not name dropped, computed on the
  /// read rather than per lookup: the sidebar asks per row per render.
  public var confined: SharedProjectSettings?
  /// The date the file had when read. A stat against this tells an edited
  /// file without a read.
  public var modificationDate: Date
  /// Why it would not parse, for the project's Hooks tab.
  public var problem: String?
  /// False until the file has been read at all this run. A first read says
  /// nothing about trust, so a launch opens with no queue of questions.
  public var hasBeenRead: Bool

  public init(
    asWritten: SharedProjectSettings? = nil, confined: SharedProjectSettings? = nil,
    modificationDate: Date = .distantPast, problem: String? = nil, hasBeenRead: Bool = false
  ) {
    self.asWritten = asWritten
    self.confined = confined
    self.modificationDate = modificationDate
    self.problem = problem
    self.hasBeenRead = hasBeenRead
  }

  /// A project whose file has not been read. Every field is the right answer
  /// for that, `modificationDate` included: `hasMoved` says yes to it.
  public static let unread = SharedSettingsSnapshot()

  /// Whether the file's date has moved since it was read, which is what a
  /// tick asks before spending a read. True for a project never read.
  public func hasMoved(_ modificationDate: Date) -> Bool {
    self.modificationDate != modificationDate || !hasBeenRead
  }
}

extension SharedSettingsSnapshot {
  /// A read that parsed, confined by the reader, which asks the disk. The
  /// date is recorded either way, so an unparsable file is not re-read.
  public mutating func recordParsed(
    _ settings: SharedProjectSettings?, confined: SharedProjectSettings?, modificationDate: Date
  ) {
    asWritten = settings
    self.confined = confined
    self.modificationDate = modificationDate
    problem = nil
    hasBeenRead = true
  }

  /// A read that failed, costing the shared settings and not the project.
  public mutating func recordFailure(problem: String, modificationDate: Date) {
    asWritten = nil
    confined = nil
    self.modificationDate = modificationDate
    self.problem = problem
    hasBeenRead = true
  }
}
