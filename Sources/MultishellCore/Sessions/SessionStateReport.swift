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

  public var version: Int
  public var state: SessionState
  /// The tab, from `MULTISHELL_SESSION` in the terminal's environment. A
  /// report without one can still name a worktree through `cwd`.
  public var sessionID: TerminalSession.ID?
  public var cwd: String?
  /// The process the state is about, so the app can notice it is gone.
  public var pid: Int32?
  /// Shown in the notification when present: "Claude needs your permission
  /// to use Bash" says more than "Waiting for input".
  public var message: String?
  /// How long the finished command ran, in seconds, when the source knows.
  /// A shell hook sets it; the GUI does not post a banner for a short one.
  public var duration: Double?

  enum CodingKeys: String, CodingKey {
    case version = "v"
    case state
    case sessionID = "session"
    case cwd
    case pid
    case message
    case duration
  }

  public init(
    state: SessionState,
    sessionID: TerminalSession.ID? = nil,
    cwd: String? = nil,
    pid: Int32? = nil,
    message: String? = nil,
    duration: Double? = nil
  ) {
    self.version = Self.protocolVersion
    self.state = state
    self.sessionID = sessionID
    self.cwd = cwd
    self.pid = pid
    self.message = message
    self.duration = duration
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
