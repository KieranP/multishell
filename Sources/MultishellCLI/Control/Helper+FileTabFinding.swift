import Foundation
import MultishellCore

extension Helper {
  /// A file's count lands with its read, which may wait on git behind another.
  private static let fileFindCountTimeout: Duration = .seconds(5)
  private static let fileFindCountInterval: Duration = .milliseconds(100)

  /// Prints the tab once its bar has counted, or as it stands at the timeout; a
  /// close, or an answer with no bar, prints at once.
  static func findInFileTab(
    _ id: UUID,
    action: FindBarAction,
    environment: [String: String],
  ) throws -> Int32 {
    let request = ControlRequest.findInFileTab(id: id, action: action)
    // Only a step is refused while the rows are read; the rest wait in the app.
    let isStep = action == .next || action == .previous
    let answer =
      try isStep
      ? answerOnceRead(request, of: id, environment)
      : output(of: request, environment: environment)
    guard action != .close, findBar(in: answer) != nil, !isCounted(answer) else {
      if let answer { print(answer) }
      return 0
    }
    let counted = try poll(every: fileFindCountInterval, for: fileFindCountTimeout) { remaining in
      try notYetWhereCutShort { () -> String? in
        let shown = try output(
          of: .describeTab(id: id),
          environment: environment,
          timeout: remaining,
        )
        return isCounted(shown) ? shown : nil
      }
    }
    if let shown = counted ?? answer { print(shown) }
    return 0
  }

  /// A step refused while the tab's rows are being read is asked again until they
  /// are, or the timeout says why not.
  private static func answerOnceRead(
    _ request: ControlRequest,
    of id: UUID,
    _ environment: [String: String],
  ) throws -> String? {
    var stillReading: ControlRefused?
    let answered = try poll(every: fileFindCountInterval, for: fileFindCountTimeout) {
      remaining -> String?? in
      try notYetWhereCutShort { () -> String?? in
        do {
          return .some(try output(of: request, environment: environment, timeout: remaining))
        } catch let refused as ControlRefused where refused.refusal == .fileTabNotRead(id: id) {
          stillReading = refused
          return nil
        }
      }
    }
    guard let answered else {
      throw stillReading ?? ControlRefused(refusal: .fileTabNotRead(id: id))
    }
    return answered
  }

  private static func isCounted(_ tab: String?) -> Bool {
    findBar(in: tab)?["total"] is Int
  }
}
