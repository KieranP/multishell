/// Which reported states post a notification for a tab nobody is looking at.
/// Not running or idle: a banner per tool call would be noise.
public struct NotificationPreference: Codable, Hashable, Sendable {
  enum CodingKeys: String, CodingKey {
    case notifiesOnAttention = "attention"
    case notifiesOnFailure = "error"
    case notifiesOnDone = "done"
  }

  /// The states a banner can be asked for, in the order the settings page
  /// lists them, most urgent first.
  public static let notifiableStates: [SessionState] = [.attention, .failed, .done]

  /// Off until asked for, which is also where the permission prompt belongs.
  static let off = Self()

  var notifiesOnAttention: Bool
  var notifiesOnFailure: Bool
  var notifiesOnDone: Bool

  init(
    notifiesOnAttention: Bool = false,
    notifiesOnFailure: Bool = false,
    notifiesOnDone: Bool = false,
  ) {
    self.notifiesOnAttention = notifiesOnAttention
    self.notifiesOnFailure = notifiesOnFailure
    self.notifiesOnDone = notifiesOnDone
  }

  /// Also reads the three-way picker these toggles replaced. An unknown
  /// name reads as off, like anything else unrecognised.
  public init(from decoder: any Decoder) throws {
    if let legacy = try? decoder.singleValueContainer().decode(String.self) {
      switch legacy {
      case "attentionOnly": self = Self(notifiesOnAttention: true)

      case "attentionAndDone":
        self = Self(
          notifiesOnAttention: true,
          notifiesOnFailure: true,
          notifiesOnDone: true,
        )

      default: self = .off
      }
      return
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Tolerated per state: a hand-edited file with one bad value costs
    // that toggle and not the other two.
    notifiesOnAttention = container.decodeTolerantly(
      Bool.self,
      forKey: .notifiesOnAttention,
      or: false,
    )
    notifiesOnFailure = container.decodeTolerantly(
      Bool.self,
      forKey: .notifiesOnFailure,
      or: false,
    )
    notifiesOnDone = container.decodeTolerantly(Bool.self, forKey: .notifiesOnDone, or: false)
  }

  /// Whether a state raises a banner. Every state answers, so a caller can
  /// hand this whatever was reported.
  public subscript(state: SessionState) -> Bool {
    get {
      switch state {
      case .attention: notifiesOnAttention
      case .failed: notifiesOnFailure
      case .done: notifiesOnDone
      case .running, .idle: false
      }
    }
    set {
      switch state {
      case .attention: notifiesOnAttention = newValue
      case .failed: notifiesOnFailure = newValue
      case .done: notifiesOnDone = newValue
      case .running, .idle: break
      }
    }
  }
}
