import Foundation
import MultishellCore

extension Helper {
  /// How long a find waits for the engine to count, which it does a turn later.
  private static let findCountTimeout: Duration = .seconds(2)
  private static let findCountInterval: Duration = .milliseconds(100)
  /// Looks a count must hold for: the engine posts a 0 as a search changes,
  /// then a running total as it reads the scrollback.
  private static let settledLooks = 3

  /// TEXT opens the bar on it; `--next`, `--previous` and `--close` act on the
  /// bar up. Prints the pane's id and its bar once the engine has counted.
  static func findInPane(
    _ id: UUID,
    text: String?,
    _ optionWords: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32 {
    let action = try findAction(
      text: text,
      optionWords,
      command: "panes find",
      topic: ControlCommand.panes.rawValue,
    )
    let answer = try output(of: .findInPane(id: id, action: action), environment: environment)
    let bar: [String: Any]? =
      switch action {
      case .close: nil

      case .open:
        try settledFind(of: id, after: answer, field: "total", environment: environment)

      case .next, .previous:
        try settledFind(of: id, after: answer, field: "selected", environment: environment)
      }
    try printJSON(["pane": id.uuidString, "find": bar.map { $0 as Any } ?? NSNull()])
    return 0
  }

  /// The pane's `find` once `field` has held one value for `settledLooks`, or
  /// as it stands at the timeout.
  private static func settledFind(
    of id: UUID,
    after answer: String?,
    field: String,
    environment: [String: String],
  ) throws -> [String: Any]? {
    var bar = findBar(in: answer)
    var held: (value: Int, looks: Int)?
    let settled = try poll(every: findCountInterval, for: findCountTimeout) { remaining in
      try notYetWhereCutShort { () -> [String: Any]? in
        bar =
          try describedPane(id, environment: environment, timeout: remaining)
          .fields["find"] as? [String: Any]
        guard let value = bar?[field] as? Int else {
          held = nil
          return nil
        }
        let looks = held?.value == value ? (held?.looks ?? 0) + 1 : 1
        held = (value, looks)
        return looks >= settledLooks ? bar : nil
      }
    }
    return settled ?? bar
  }
}
