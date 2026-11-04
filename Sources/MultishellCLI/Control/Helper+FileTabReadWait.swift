import Foundation
import MultishellCore

extension Helper {
  /// A file's rows and count land with its read, which may wait on git behind another.
  private static let fileTabReadTimeout: Duration = .seconds(5)
  private static let fileTabReadPollInterval: Duration = .milliseconds(100)

  /// Asked again while the tab's rows are read, each ask given the usual timeout, as
  /// one cut short may still act in the app (agents.md, a file tab's arrows and find).
  static func askOnceRead(
    _ request: ControlRequest,
    of id: UUID,
    environment: [String: String],
  ) throws -> Int32 {
    var stillReading: ControlRefused?
    let answered = try poll(every: fileTabReadPollInterval, for: fileTabReadTimeout) {
      _ -> String?? in
      do {
        return .some(try output(of: request, environment: environment))
      } catch let refused as ControlRefused where refused.refusal == .fileTabNotRead(id: id) {
        stillReading = refused
        return nil
      }
    }
    guard let answered else {
      throw stillReading ?? ControlRefused(refusal: .fileTabNotRead(id: id))
    }
    if let answered { print(answered) }
    return 0
  }
}
