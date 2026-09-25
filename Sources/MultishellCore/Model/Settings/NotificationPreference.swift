/// Which reported states post a notification for a tab nobody is looking at.
/// Not running or idle: a banner per tool call would be noise.
public struct NotificationPreference: Codable, Hashable, Sendable {
  /// The states a banner can be asked for, in the order the settings page
  /// lists them, most urgent first.
  public static let notifiableStates: [SessionState] = [.attention, .failed, .done]

  public var attention: Bool
  public var failed: Bool
  public var done: Bool

  /// Off until asked for, which is also where the permission prompt belongs.
  static let off = NotificationPreference()

  init(attention: Bool = false, failed: Bool = false, done: Bool = false) {
    self.attention = attention
    self.failed = failed
    self.done = done
  }

  /// Whether a state raises a banner. Every state answers, so a caller can
  /// hand this whatever was reported.
  public subscript(state: SessionState) -> Bool {
    get {
      switch state {
      case .attention: attention
      case .failed: failed
      case .done: done
      case .running, .idle: false
      }
    }
    set {
      switch state {
      case .attention: attention = newValue
      case .failed: failed = newValue
      case .done: done = newValue
      case .running, .idle: break
      }
    }
  }

  enum CodingKeys: String, CodingKey {
    case attention
    case failed = "error"
    case done
  }

  /// Also reads the three-way picker these toggles replaced. An unknown
  /// name reads as off, like anything else unrecognised.
  public init(from decoder: any Decoder) throws {
    if let legacy = try? decoder.singleValueContainer().decode(String.self) {
      switch legacy {
      case "attentionOnly": self = NotificationPreference(attention: true)
      case "attentionAndDone":
        self = NotificationPreference(attention: true, failed: true, done: true)
      default: self = .off
      }
      return
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Tolerated per state: a hand-edited file with one bad value costs
    // that toggle and not the other two.
    attention = container.decodeTolerantly(Bool.self, forKey: .attention, or: false)
    failed = container.decodeTolerantly(Bool.self, forKey: .failed, or: false)
    done = container.decodeTolerantly(Bool.self, forKey: .done, or: false)
  }
}
