import Foundation
import MultishellCore

extension Helper {
  /// A file's rows and count land with its read, which may wait on git behind another.
  private static let fileTabReadTimeout: Duration = .seconds(5)
  private static let fileTabReadPollInterval: Duration = .milliseconds(100)

  /// Asked again while a tab's rows are read, each ask its own timeout (agents/command-line.md);
  /// `id` `nil` waits on any tab, as `review add` names a file, not a tab.
  static func askOnceRead(
    _ request: ControlRequest,
    of id: UUID?,
    environment: [String: String],
  ) throws -> Int32 {
    var stillReading: ControlRefused?
    let answered = try poll(every: fileTabReadPollInterval, for: fileTabReadTimeout) {
      _ -> String?? in
      do {
        return .some(try output(of: request, environment: environment))
      } catch let refused as ControlRefused where isStillReading(refused.refusal, tab: id) {
        stillReading = refused
        return nil
      }
    }
    guard let answered else {
      // The first look always runs, so a wait that ran out ends on its refusal.
      if let stillReading { throw stillReading }
      return 1
    }
    if let answered { print(answered) }
    return 0
  }

  private static func isStillReading(_ refusal: ControlRefusal, tab id: UUID?) -> Bool {
    guard case .fileTabNotRead(let reading) = refusal else { return false }
    return id.map { $0 == reading } ?? true
  }
}
