import Foundation

/// One message over the inbound channel: a hook, the helper or any script
/// saying what state a session is in.
///
/// JSON, one object per line. `v` is the protocol version this message was
/// written for; a helper left behind by an older install keeps working
/// against a newer app because fields are only ever added, and a message
/// whose `state` this build does not know is dropped rather than failing
/// the connection.
public struct SessionStateReport: Codable, Hashable, Sendable {
  public static let protocolVersion = 1
  /// More than a notification banner shows, and far inside what the channel
  /// carries.
  public static let maximumMessageLength = 500

  public var version: Int
  public var state: SessionState
  /// The tab, from `MULTISHELL_SESSION` in the terminal's environment. A
  /// report without one can still name a worktree through `cwd`.
  public var sessionID: TerminalSession.ID?
  public var cwd: String?
  /// The process the state is about, so the app can notice it is gone.
  public var pid: Int32?
  /// Shown in the notification when present: "Claude needs your permission
  /// to use Bash" says more than "Waiting for input". Trimmed to
  /// `maximumMessageLength` as it is set: the channel drops a line longer
  /// than 64 KB as not speaking the protocol, and a permission prompt
  /// quoting a very long command would otherwise lose the report that
  /// matters most, the one saying the agent is waiting.
  public var message: String?
  /// How long the finished command ran, in seconds, when the source knows.
  /// A shell hook sets it; the GUI does not post a banner for a short one.
  public var duration: Double?
  /// Which agent the report came from, by catalogue id. An agent's hooks
  /// set it; a shell hook leaves it out. It says what is at a pane's prompt,
  /// which the tab's own `agentID` cannot: an agent is usually started by
  /// hand in a plain shell tab, and a tab opened for one keeps its id long
  /// after the agent has quit.
  public var agent: String?

  enum CodingKeys: String, CodingKey {
    case version = "v"
    case state
    case sessionID = "session"
    case cwd
    case pid
    case message
    case duration
    case agent
  }

  public init(
    state: SessionState,
    sessionID: TerminalSession.ID? = nil,
    cwd: String? = nil,
    pid: Int32? = nil,
    message: String? = nil,
    duration: Double? = nil,
    agent: String? = nil
  ) {
    self.version = Self.protocolVersion
    self.state = state
    self.sessionID = sessionID
    self.cwd = cwd
    self.pid = pid
    self.message = Self.trimmed(message)
    self.duration = duration
    self.agent = agent
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
    state = try c.decode(SessionState.self, forKey: .state)
    sessionID = try c.decodeIfPresent(UUID.self, forKey: .sessionID)
    cwd = try c.decodeIfPresent(String.self, forKey: .cwd)
    pid = try c.decodeIfPresent(Int32.self, forKey: .pid)
    message = try c.decodeIfPresent(String.self, forKey: .message)
    duration = try c.decodeIfPresent(Double.self, forKey: .duration)
    agent = try c.decodeIfPresent(String.self, forKey: .agent)
  }

  private static func trimmed(_ message: String?) -> String? {
    guard let message, message.count > maximumMessageLength else { return message }
    return message.prefix(maximumMessageLength) + "…"
  }

  /// `nil` for anything that is not one well-formed report: the channel is
  /// a file any process of the user's can write to, and a bad line must
  /// cost that line only.
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
