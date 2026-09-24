import Foundation

/// One message over the inbound channel, JSON one object per line. Fields
/// are only ever added; see Docs/design/agents.md.
public struct SessionStateReport: Codable, Hashable, Sendable {
  public static let protocolVersion = 1
  /// More than a notification banner shows, and far inside what the channel
  /// carries.
  static let maximumMessageLength = 500
  /// A week. Longer than any command the board is asked to time, and short
  /// of what `Int(_:)` cannot hold.
  static let maximumDuration: Double = 7 * 24 * 60 * 60

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
  /// The foreground command a shell just started, its first word only; see
  /// Docs/design/agents.md.
  public var command: String?
  /// Set on the reports the injected shell integration sends, which are the
  /// only ones that take an agent's mark back; see Docs/design/agents.md.
  public var isShell: Bool?
  /// Set where the report moves a dot and another about the same thing will
  /// raise the banner. Absent keeps an older helper's banners.
  public var silent: Bool?
  /// The count a helper from before workers had names wrote: `1` started, `-1`
  /// ended. Read as an unnamed worker; see Docs/design/agents.md.
  public var subagents: Int?
  /// A subagent starting, calling a tool or ending. The app keeps the
  /// roster; see Docs/design/agents.md.
  public var subagent: SubagentReport?
  /// Set on the prompt that starts a turn, which empties the roster.
  public var startsTurn: Bool?
  /// Set on an agent's session start, which one agent sends after its first
  /// prompt; see Docs/design/agents.md.
  public var startsSession: Bool?
  /// The shells the agent left running at its Stop, by pid; their exit is
  /// the only end they report. See Docs/design/agents.md.
  public var backgroundShells: [Int32]?
  /// Set on a Stop from an agent that takes another turn when the work it
  /// left out ends, so that turn pays the Done; see Docs/design/agents.md.
  public var resumesAfterWorkers: Bool?
  /// The agent's own id for the conversation, from an agent that runs a
  /// subagent as a conversation of its own; see Docs/design/agents.md.
  public var conversationID: String?

  enum CodingKeys: String, CodingKey {
    case version = "v"
    case state
    case sessionID = "session"
    case cwd
    case pid
    case message
    case duration
    case agent
    case command
    case isShell = "shell"
    case silent
    case subagents
    case subagent
    case startsTurn = "turn"
    case startsSession = "start"
    case backgroundShells = "shells"
    case resumesAfterWorkers = "resumes"
    case conversationID = "conversation"
  }

  public init(
    state: SessionState,
    sessionID: TerminalSession.ID? = nil,
    cwd: String? = nil,
    pid: Int32? = nil,
    message: String? = nil,
    duration: Double? = nil,
    agent: String? = nil,
    command: String? = nil,
    isShell: Bool? = nil,
    silent: Bool? = nil,
    subagents: Int? = nil,
    subagent: SubagentReport? = nil,
    startsTurn: Bool? = nil,
    startsSession: Bool? = nil,
    backgroundShells: [Int32]? = nil,
    resumesAfterWorkers: Bool? = nil,
    conversationID: String? = nil
  ) {
    self.version = Self.protocolVersion
    self.state = state
    self.sessionID = sessionID
    self.cwd = Self.path(cwd)
    self.pid = pid
    self.message = Self.trimmed(message)
    self.duration = Self.bounded(duration)
    self.agent = Self.identifier(agent)
    self.command = Self.commandWord(command)
    self.isShell = isShell
    self.silent = silent
    self.subagents = subagents ?? Self.count(of: subagent)
    self.subagent = subagent
    self.startsTurn = startsTurn
    self.startsSession = startsSession
    self.backgroundShells = backgroundShells.map { Array($0.prefix(Self.rosterLimit)) }
    self.resumesAfterWorkers = resumesAfterWorkers
    self.conversationID = Self.identifier(conversationID)
  }

  /// What an app that reads only the count should make of a worker. A tool
  /// call counts for nothing: each would otherwise add a worker to its roster.
  private static func count(of subagent: SubagentReport?) -> Int? {
    switch subagent?.phase {
    case .started: 1
    case .ended: -1
    case .working, nil: nil
    }
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decode(Int.self, forKey: .version, or: 1)
    state = try container.decode(SessionState.self, forKey: .state)
    sessionID = try container.decodeIfPresent(UUID.self, forKey: .sessionID)
    cwd = Self.path(try container.decodeIfPresent(String.self, forKey: .cwd))
    pid = try container.decodeIfPresent(Int32.self, forKey: .pid)
    // Trimmed on the way in as well as out: any process of the user's may
    // write a line, so the cap is the reader's rule.
    message = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .message))
    duration = Self.bounded(try container.decodeIfPresent(Double.self, forKey: .duration))
    agent = Self.identifier(try container.decodeIfPresent(String.self, forKey: .agent))
    command = Self.commandWord(try container.decodeIfPresent(String.self, forKey: .command))
    isShell = try container.decodeIfPresent(Bool.self, forKey: .isShell)
    silent = try container.decodeIfPresent(Bool.self, forKey: .silent)
    subagents = try container.decodeIfPresent(Int.self, forKey: .subagents)
    subagent = try container.decodeIfPresent(SubagentReport.self, forKey: .subagent)
    startsTurn = try container.decodeIfPresent(Bool.self, forKey: .startsTurn)
    startsSession = try container.decodeIfPresent(Bool.self, forKey: .startsSession)
    backgroundShells = try container.decodeIfPresent([Int32].self, forKey: .backgroundShells)
      .map { Array($0.prefix(Self.rosterLimit)) }
    resumesAfterWorkers = try container.decodeIfPresent(Bool.self, forKey: .resumesAfterWorkers)
    conversationID = Self.identifier(
      try container.decodeIfPresent(String.self, forKey: .conversationID))
  }

  /// The roster change the report carries, an older helper's count read as
  /// an unnamed worker starting or ending.
  public var subagentChange: SubagentReport? {
    if let subagent { return subagent }
    switch subagents {
    case .some(let count) where count > 0:
      return SubagentReport(id: SubagentReport.anonymousID, phase: .started)
    case .some(let count) where count < 0:
      return SubagentReport(id: SubagentReport.anonymousID, phase: .ended)
    default:
      return nil
    }
  }

  /// The first word without its path. The reader's rule, not the hook's: any
  /// process of the user's can write a line.
  private static func commandWord(_ command: String?) -> String? {
    guard let word = command?.split(whereSeparator: \.isWhitespace).first,
      let name = word.split(separator: "/").last
    else { return nil }
    return identifier(String(name))
  }

  /// macOS's PATH_MAX; a longer one is no directory a worktree could be.
  static let maximumPathLength = 1024

  private static func path(_ path: String?) -> String? {
    guard let path, path.utf8.count <= maximumPathLength else { return nil }
    return path
  }

  /// A duration outside what a command could have taken is a writer's
  /// number rather than a clock's, and is dropped as the message is capped.
  private static func bounded(_ duration: Double?) -> Double? {
    guard let duration, duration.isFinite, duration >= 0, duration <= maximumDuration
    else { return nil }
    return duration
  }

  /// Longer than any agent's id, and dropped rather than cut: a cut one
  /// would name a different worker.
  static let maximumIdentifierLength = 128

  /// The places a model's roster holds and the shells a report names, or an agent
  /// never ending its workers or a Stop naming thousands grows it for good.
  public static let rosterLimit = 64

  private static func identifier(_ id: String?) -> String? {
    guard let id, !id.isEmpty, id.count <= maximumIdentifierLength else { return nil }
    return id
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
