import Foundation

/// One message over the inbound channel, JSON one object per line. Fields
/// are only ever added; see docs/design/agents.md.
public struct SessionStateReport: Codable, Hashable, Sendable {
  public static let protocolVersion = 1
  /// More than a notification banner shows, and far inside what the channel
  /// carries.
  public static let maximumMessageLength = 500
  /// A week. Longer than any command the board is asked to time, and short
  /// of what `Int(_:)` cannot hold.
  public static let maximumDuration: Double = 7 * 24 * 60 * 60

  public var version: Int
  public var state: SessionState
  /// The tab, from `MULTISHELL_SESSION` in the terminal's environment. A
  /// report without one can still name a worktree through `cwd`.
  public var sessionID: TerminalSession.ID?
  public var cwd: String?
  /// The process the state is about, so the app can notice it is gone.
  public var pid: Int32?
  /// Shown in the notification when present. Trimmed as it is set: the
  /// channel drops a line over 64 KB, losing the report that matters most.
  public var message: String?
  /// How long the finished command ran, in seconds, when the source knows.
  /// A shell hook sets it; the GUI does not post a banner for a short one.
  public var duration: Double?
  /// Which agent the report came from. Says what is at a pane's prompt,
  /// which the tab's own `agentID` cannot; see `ReportedAgent`.
  public var agent: String?
  /// Set where the report moves a dot and another about the same thing will
  /// raise the banner. Absent keeps an older helper's banners.
  public var silent: Bool?
  /// What this does to the count of background workers outstanding: `1`
  /// started, `-1` ended. The app counts; see docs/design/agents.md.
  public var subagents: Int?

  enum CodingKeys: String, CodingKey {
    case version = "v"
    case state
    case sessionID = "session"
    case cwd
    case pid
    case message
    case duration
    case agent
    case silent
    case subagents
  }

  public init(
    state: SessionState,
    sessionID: TerminalSession.ID? = nil,
    cwd: String? = nil,
    pid: Int32? = nil,
    message: String? = nil,
    duration: Double? = nil,
    agent: String? = nil,
    silent: Bool? = nil,
    subagents: Int? = nil
  ) {
    self.version = Self.protocolVersion
    self.state = state
    self.sessionID = sessionID
    self.cwd = cwd
    self.pid = pid
    self.message = Self.trimmed(message)
    self.duration = Self.bounded(duration)
    self.agent = agent
    self.silent = silent
    self.subagents = subagents
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decode(Int.self, forKey: .version, or: 1)
    state = try container.decode(SessionState.self, forKey: .state)
    sessionID = try container.decodeIfPresent(UUID.self, forKey: .sessionID)
    cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
    pid = try container.decodeIfPresent(Int32.self, forKey: .pid)
    // Trimmed on the way in as well as out: any process of the user's may
    // write a line, so the cap is the reader's rule.
    message = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .message))
    duration = Self.bounded(try container.decodeIfPresent(Double.self, forKey: .duration))
    agent = try container.decodeIfPresent(String.self, forKey: .agent)
    silent = try container.decodeIfPresent(Bool.self, forKey: .silent)
    subagents = try container.decodeIfPresent(Int.self, forKey: .subagents)
  }

  /// A duration outside what a command could have taken is a writer's
  /// number rather than a clock's, and is dropped as the message is capped.
  private static func bounded(_ duration: Double?) -> Double? {
    guard let duration, duration.isFinite, duration >= 0, duration <= maximumDuration
    else { return nil }
    return duration
  }

  private static func trimmed(_ message: String?) -> String? {
    guard let message, message.count > maximumMessageLength else { return message }
    return message.prefix(maximumMessageLength) + "…"
  }

  /// `nil` for anything that is not one well-formed report: any process may
  /// write to the channel, so a bad line costs that line only.
  public static func parse(_ line: String) -> SessionStateReport? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return try? JSONDecoder().decode(SessionStateReport.self, from: Data(trimmed.utf8))
  }

  /// One line, newline-terminated, ready for the socket.
  public func encodedLine() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(self), as: UTF8.self) + "\n"
  }
}
