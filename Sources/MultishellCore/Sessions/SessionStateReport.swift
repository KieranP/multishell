import Foundation

/// One message over the inbound channel, JSON one object per line. Fields
/// are only ever added; see Docs/design/agents.md.
public struct SessionStateReport: Codable, Hashable, Sendable {
  public static let protocolVersion = 1

  var version: Int
  public var state: SessionState
  /// The tab, from `MULTISHELL_SESSION` in the terminal's environment. A
  /// report without one can still name a worktree through `cwd`.
  public var sessionID: TerminalSession.ID?
  public var cwd: String?
  /// The process the state is about, so the app can notice it is gone.
  public var pid: Int32?
  /// Shown in the notification when present. Truncated as it is set: the
  /// channel drops a line over 64 KB, losing the report that matters most.
  public var message: String?
  /// How long the finished command ran, in seconds, when the source knows.
  /// A shell hook sets it; the GUI does not post a banner for a short one.
  public var duration: Double?
  /// Which agent the report came from, by catalogue id: what is at a pane's
  /// prompt, which the tab's own `agentID` cannot say; see `ReportedAgent`.
  public var agentID: String?
  /// The foreground command a shell just started, its first word only; see
  /// Docs/design/agents.md.
  public var command: String?
  /// Set on the reports the injected shell integration sends, which are the
  /// only ones that take an agent's mark back; see Docs/design/agents.md.
  public var isFromShellIntegration: Bool?
  /// Set where the report moves a dot and another about the same thing will
  /// raise the banner. Absent keeps an older helper's banners.
  public var isSilent: Bool?
  /// The count a helper from before workers had names wrote: `1` started, `-1`
  /// ended. Read as an unnamed worker; see Docs/design/agents.md.
  var legacySubagentCount: Int?
  /// A subagent starting, calling a tool or ending. The app keeps the
  /// roster; see Docs/design/agents.md.
  public var subagent: SubagentReport?
  /// Set on the prompt that starts a turn, which keeps only the workers a held
  /// Stop saw out; see Docs/design/agents.md.
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
  /// Everything a Stop says is still out, shells aside, which outranks what
  /// the hooks said; see Docs/design/agents.md.
  public var workersOut: [SubagentReport]?
  /// Set on a Stop the agent takes another turn straight after, a finished
  /// task's notice still being queued; see Docs/design/agents.md.
  public var turnFollows: Bool?

  enum CodingKeys: String, CodingKey {
    case version = "v"
    case state
    case sessionID = "session"
    case cwd
    case pid
    case message
    case duration
    case agentID = "agent"
    case command
    case isFromShellIntegration = "shell"
    case isSilent = "silent"
    case legacySubagentCount = "subagents"
    case subagent
    case startsTurn = "turn"
    case startsSession = "start"
    case backgroundShells = "shells"
    case resumesAfterWorkers = "resumes"
    case conversationID = "conversation"
    case workersOut = "out"
    case turnFollows = "follows"
  }

  public init(
    state: SessionState,
    sessionID: TerminalSession.ID? = nil,
    cwd: String? = nil,
    pid: Int32? = nil,
    message: String? = nil,
    duration: Double? = nil,
    agentID: String? = nil,
    command: String? = nil,
    isFromShellIntegration: Bool? = nil,
    isSilent: Bool? = nil,
    subagent: SubagentReport? = nil,
    startsTurn: Bool? = nil,
    startsSession: Bool? = nil,
    backgroundShells: [Int32]? = nil,
    resumesAfterWorkers: Bool? = nil,
    conversationID: String? = nil,
    workersOut: [SubagentReport]? = nil,
    turnFollows: Bool? = nil
  ) {
    self.version = Self.protocolVersion
    self.state = state
    self.sessionID = sessionID
    self.cwd = Self.boundedPath(cwd)
    self.pid = pid
    self.message = Self.truncatedMessage(message)
    self.duration = Self.boundedDuration(duration)
    self.agentID = Self.boundedIdentifier(agentID)
    self.command = Self.commandWord(command)
    self.isFromShellIntegration = isFromShellIntegration
    self.isSilent = isSilent
    self.legacySubagentCount = Self.legacyCount(of: subagent)
    self.subagent = subagent
    self.startsTurn = startsTurn
    self.startsSession = startsSession
    self.backgroundShells = Self.boundedShells(backgroundShells)
    self.resumesAfterWorkers = resumesAfterWorkers
    self.conversationID = Self.boundedIdentifier(conversationID)
    self.workersOut = Self.boundedWorkers(workersOut)
    self.turnFollows = turnFollows
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Through the memberwise init, so what is read is capped as what is sent:
    // any process of the user's may write a line, so the caps are the reader's.
    self.init(
      state: try container.decode(SessionState.self, forKey: .state),
      sessionID: try container.decodeIfPresent(UUID.self, forKey: .sessionID),
      cwd: try container.decodeIfPresent(String.self, forKey: .cwd),
      pid: try container.decodeIfPresent(Int32.self, forKey: .pid),
      message: try container.decodeIfPresent(String.self, forKey: .message),
      duration: try container.decodeIfPresent(Double.self, forKey: .duration),
      agentID: try container.decodeIfPresent(String.self, forKey: .agentID),
      command: try container.decodeIfPresent(String.self, forKey: .command),
      isFromShellIntegration: try container.decodeIfPresent(
        Bool.self, forKey: .isFromShellIntegration),
      isSilent: try container.decodeIfPresent(Bool.self, forKey: .isSilent),
      subagent: try container.decodeIfPresent(SubagentReport.self, forKey: .subagent),
      startsTurn: try container.decodeIfPresent(Bool.self, forKey: .startsTurn),
      startsSession: try container.decodeIfPresent(Bool.self, forKey: .startsSession),
      backgroundShells: try container.decodeIfPresent([Int32].self, forKey: .backgroundShells),
      resumesAfterWorkers: try container.decodeIfPresent(Bool.self, forKey: .resumesAfterWorkers),
      conversationID: try container.decodeIfPresent(String.self, forKey: .conversationID),
      workersOut: try container.decodeIfPresent([SubagentReport].self, forKey: .workersOut),
      turnFollows: try container.decodeIfPresent(Bool.self, forKey: .turnFollows))
    version = try container.decode(Int.self, forKey: .version, or: 1)
    legacySubagentCount = try container.decodeIfPresent(Int.self, forKey: .legacySubagentCount)
  }

  /// The roster change the report carries, an older helper's count read as
  /// an unnamed worker starting or ending.
  public var subagentChange: SubagentReport? {
    if let subagent { return subagent }
    switch legacySubagentCount {
    case .some(let count) where count > 0:
      return SubagentReport(id: SubagentReport.anonymousID, phase: .started)
    case .some(let count) where count < 0:
      return SubagentReport(id: SubagentReport.anonymousID, phase: .ended)
    default:
      return nil
    }
  }

  /// What an app that reads only the count should make of a worker. A tool
  /// call counts for nothing: each would otherwise add a worker to its roster.
  static func legacyCount(of subagent: SubagentReport?) -> Int? {
    switch subagent?.phase {
    case .started: 1
    case .ended: -1
    case .working, nil: nil
    }
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
