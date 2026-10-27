import Foundation

/// Antigravity's camelCase payload, read on 1.4.8; see Docs/design/agents.md.
extension AgentHookPayload {
  static let antigravityStop = "Stop"
  /// The events a cancelled and a failed Stop are reported as.
  static let antigravityCancelledStop = "StopCancelled"
  static let antigravityFailedStop = "StopFailed"

  /// What a Stop is reported as, by why the turn ended. Any other reason,
  /// `NO_TOOL_CALL` among them, is the turn's answer.
  private static let antigravityStopNames = [
    "USER_CANCELED": antigravityCancelledStop,
    "ERROR": antigravityFailedStop,
  ]

  /// The hook line names the event and the first workspace is the directory,
  /// the hook running in the folder that holds its hooks file.
  init?(antigravityJSON data: Data, eventName: String) {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    var reportedName = eventName
    if eventName == Self.antigravityStop, let reason = object["terminationReason"] as? String,
      let stopName = Self.antigravityStopNames[reason]
    {
      reportedName = stopName
    }
    self.init(
      eventName: reportedName,
      workingDirectory: (object["workspacePaths"] as? [String])?.first,
      message: reportedName == Self.antigravityFailedStop
        ? (object["error"] as? String)?.nonEmpty : nil,
    )
  }
}
