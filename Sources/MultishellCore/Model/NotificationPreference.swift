import Foundation

/// Which reported states post a system notification for a tab the user is
/// not looking at. Running and idle are not among them: a banner about
/// every tool call would be noise.
public struct NotificationPreference: Codable, Hashable, Sendable {
  /// The states a banner can be asked for, in the order the settings tab
  /// lists them, most urgent first.
  public static let notifiableStates: [SessionState] = [.attention, .error, .done]

  public var attention: Bool
  public var error: Bool
  public var done: Bool

  /// Off until asked for: a banner about a tab is welcome once expected and
  /// startling before, and turning one on is where the permission prompt
  /// belongs.
  public static let off = NotificationPreference()
  public static let `default` = NotificationPreference.off

  public init(attention: Bool = false, error: Bool = false, done: Bool = false) {
    self.attention = attention
    self.error = error
    self.done = done
  }

  /// Whether a state raises a banner. Every state answers, so a caller can
  /// hand this whatever was reported.
  public subscript(state: SessionState) -> Bool {
    get {
      switch state {
      case .attention: attention
      case .error: error
      case .done: done
      case .running, .idle: false
      }
    }
    set {
      switch state {
      case .attention: attention = newValue
      case .error: error = newValue
      case .done: done = newValue
      case .running, .idle: break
      }
    }
  }

  enum CodingKeys: String, CodingKey {
    case attention
    case error
    case done
  }

  /// Also reads the three-way picker these toggles replaced, so a state
  /// file written before them keeps what it was set to. A name from a
  /// build that knew a fourth setting reads as off, like anything else
  /// unrecognised.
  public init(from decoder: any Decoder) throws {
    if let legacy = try? decoder.singleValueContainer().decode(String.self) {
      switch legacy {
      case "attentionOnly": self = NotificationPreference(attention: true)
      case "attentionAndDone":
        self = NotificationPreference(attention: true, error: true, done: true)
      default: self = .off
      }
      return
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // `try?` per state: a hand-edited file with one bad value costs that
    // toggle and not the other two.
    attention = (try? container.decodeIfPresent(Bool.self, forKey: .attention)) ?? false
    error = (try? container.decodeIfPresent(Bool.self, forKey: .error)) ?? false
    done = (try? container.decodeIfPresent(Bool.self, forKey: .done)) ?? false
  }
}
