import Foundation

/// One message over the inbound channel, JSON one object per line. Fields
/// are only ever added; see Docs/design/agents.md.
public struct SessionStateReport: Codable, Hashable, Sendable {
  public static let protocolVersion = 1

  var version: Int
  public internal(set) var state: SessionState
  /// The tab, from `MULTISHELL_SESSION` in the terminal's environment. A
  /// report without one can still name a worktree through `workingDirectory`.
  public internal(set) var sessionID: TerminalSession.ID?
  public internal(set) var workingDirectory: String?
  /// The process the state is about, so the app can notice it is gone.
  public internal(set) var pid: Int32?
  /// Shown in the notification when present. Truncated as it is set: the
  /// channel drops a line over 64 KB, losing the report that matters most.
  public internal(set) var message: String?
  /// How long the finished command ran, in seconds, when the source knows.
  /// A shell hook sets it; the GUI does not post a banner for a short one.
  public internal(set) var duration: Double?
  /// Which agent the report came from, by catalogue id: what is at a pane's
  /// prompt, which the tab's own `agentID` cannot say; see `ReportedAgent`.
  public internal(set) var agentID: String?
  /// The foreground command a shell just started, its first word only; see
  /// Docs/design/agents.md.
  public internal(set) var command: String?
  /// Set on the reports the injected shell integration sends, which are the
  /// only ones that take an agent's mark back; see Docs/design/agents.md.
  public internal(set) var isFromShellIntegration: Bool?
  /// Set where the report moves a dot and another about the same thing will
  /// raise the banner. Absent keeps an older helper's banners.
  public internal(set) var isSilent: Bool?
  /// The count a helper from before workers had names wrote: `1` started, `-1`
  /// ended. Read as an unnamed worker; see Docs/design/agents.md.
  var legacyWorkerCount: Int?
  /// A worker starting, calling a tool or ending. The app keeps the
  /// roster; see Docs/design/agents.md.
  var worker: WorkerReport?
  /// Set on the prompt that starts a turn, which keeps only the workers a held
  /// Stop saw out; see Docs/design/agents.md.
  public internal(set) var startsTurn: Bool?
  /// Set on an agent's session start, which one agent sends after its first
  /// prompt; see Docs/design/agents.md.
  public internal(set) var startsSession: Bool?
  /// The shells the agent left running at its Stop, by pid; their exit is
  /// the only end they report. See Docs/design/agents.md.
  public internal(set) var backgroundShells: [Int32]?
  /// Set on a Stop from an agent that takes another turn when the work it
  /// left out ends, so that turn pays the Done; see Docs/design/agents.md.
  public internal(set) var resumesAfterWorkers: Bool?
  /// The agent's own id for the conversation, from an agent that runs a
  /// subagent as a conversation of its own; see Docs/design/agents.md.
  public internal(set) var conversationID: String?
  /// Everything a Stop says is still out, shells aside, which outranks what
  /// the hooks said; see Docs/design/agents.md.
  public internal(set) var workersOut: [WorkerReport]?
  /// Set on a Stop the agent takes another turn straight after, a finished
  /// task's notice still being queued; see Docs/design/agents.md.
  public internal(set) var turnFollows: Bool?
  /// Set where the agent waits on its own question though its message says
  /// permission; the app words it, the helper having no catalogue.
  public internal(set) var asksQuestion: Bool?

  enum CodingKeys: String, CodingKey {
    case version = "v"
    case state
    case sessionID = "session"
    case workingDirectory = "cwd"
    case pid
    case message
    case duration
    case agentID = "agent"
    case command
    case isFromShellIntegration = "shell"
    case isSilent = "silent"
    case legacyWorkerCount = "subagents"
    case worker = "subagent"
    case startsTurn = "turn"
    case startsSession = "start"
    case backgroundShells = "shells"
    case resumesAfterWorkers = "resumes"
    case conversationID = "conversation"
    case workersOut = "out"
    case turnFollows = "follows"
    case asksQuestion = "question"
  }

  public init(
    state: SessionState,
    sessionID: TerminalSession.ID? = nil,
    workingDirectory: String? = nil,
    pid: Int32? = nil,
    message: String? = nil,
    duration: Double? = nil,
    agentID: String? = nil,
    command: String? = nil,
    isFromShellIntegration: Bool? = nil,
    isSilent: Bool? = nil,
    worker: WorkerReport? = nil,
    startsTurn: Bool? = nil,
    startsSession: Bool? = nil,
    backgroundShells: [Int32]? = nil,
    resumesAfterWorkers: Bool? = nil,
    conversationID: String? = nil,
    workersOut: [WorkerReport]? = nil,
    turnFollows: Bool? = nil,
    asksQuestion: Bool? = nil
  ) {
    self.version = Self.protocolVersion
    self.state = state
    self.sessionID = sessionID
    self.workingDirectory = Self.boundedPath(workingDirectory)
    self.pid = pid
    self.message = Self.truncatedMessage(message)
    self.duration = Self.boundedDuration(duration)
    self.agentID = Self.boundedIdentifier(agentID)
    self.command = Self.commandWord(command)
    self.isFromShellIntegration = isFromShellIntegration
    self.isSilent = isSilent
    self.legacyWorkerCount = Self.legacyCount(of: worker)
    self.worker = worker
    self.startsTurn = startsTurn
    self.startsSession = startsSession
    self.backgroundShells = Self.boundedShells(backgroundShells)
    self.resumesAfterWorkers = resumesAfterWorkers
    self.conversationID = Self.boundedIdentifier(conversationID)
    self.workersOut = Self.boundedWorkers(workersOut)
    self.turnFollows = turnFollows
    self.asksQuestion = asksQuestion
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Through the memberwise init, so what is read is capped as what is sent:
    // any process of the user's may write a line, so the caps are the reader's.
    self.init(
      state: try container.decode(SessionState.self, forKey: .state),
      sessionID: try container.decodeIfPresent(UUID.self, forKey: .sessionID),
      workingDirectory: try container.decodeIfPresent(String.self, forKey: .workingDirectory),
      pid: try container.decodeIfPresent(Int32.self, forKey: .pid),
      message: try container.decodeIfPresent(String.self, forKey: .message),
      duration: try container.decodeIfPresent(Double.self, forKey: .duration),
      agentID: try container.decodeIfPresent(String.self, forKey: .agentID),
      command: try container.decodeIfPresent(String.self, forKey: .command),
      isFromShellIntegration: try container.decodeIfPresent(
        Bool.self, forKey: .isFromShellIntegration),
      isSilent: try container.decodeIfPresent(Bool.self, forKey: .isSilent),
      worker: try container.decodeIfPresent(WorkerReport.self, forKey: .worker),
      startsTurn: try container.decodeIfPresent(Bool.self, forKey: .startsTurn),
      startsSession: try container.decodeIfPresent(Bool.self, forKey: .startsSession),
      backgroundShells: try container.decodeIfPresent([Int32].self, forKey: .backgroundShells),
      resumesAfterWorkers: try container.decodeIfPresent(Bool.self, forKey: .resumesAfterWorkers),
      conversationID: try container.decodeIfPresent(String.self, forKey: .conversationID),
      workersOut: try container.decodeIfPresent([WorkerReport].self, forKey: .workersOut),
      turnFollows: try container.decodeIfPresent(Bool.self, forKey: .turnFollows),
      asksQuestion: try container.decodeIfPresent(Bool.self, forKey: .asksQuestion))
    version = try container.decode(Int.self, forKey: .version, or: 1)
    legacyWorkerCount = try container.decodeIfPresent(Int.self, forKey: .legacyWorkerCount)
  }

  /// The roster change the report carries, an older helper's count read as
  /// an unnamed worker starting or ending.
  public var workerChange: WorkerReport? {
    if let worker { return worker }
    switch legacyWorkerCount {
    case .some(let count) where count > 0:
      return WorkerReport(id: WorkerReport.anonymousID, phase: .started)
    case .some(let count) where count < 0:
      return WorkerReport(id: WorkerReport.anonymousID, phase: .ended)
    default:
      return nil
    }
  }

  /// What an app that reads only the count should make of a worker. A tool
  /// call counts for nothing: each would otherwise add a worker to its roster.
  static func legacyCount(of worker: WorkerReport?) -> Int? {
    switch worker?.phase {
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
