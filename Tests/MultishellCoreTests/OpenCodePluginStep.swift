/// A step handed to the driver: a hook by name, with whatever OpenCode
/// passes it.
struct OpenCodePluginStep: Encodable {
  var hook: String
  var input: [String: String]?
  var output: [String: AnyEncodable]?
  var event: [String: AnyEncodable]?

  static func message(session: String?, inSecondArgument: Bool = false) -> OpenCodePluginStep {
    guard let session else { return OpenCodePluginStep(hook: "chat.message", input: [:]) }
    return inSecondArgument
      ? OpenCodePluginStep(
        hook: "chat.message", input: [:],
        output: ["message": AnyEncodable(["sessionID": session])])
      : OpenCodePluginStep(hook: "chat.message", input: ["sessionID": session])
  }

  /// The prompt OpenCode sends itself when a background child ends.
  static func synthetic(session: String) -> OpenCodePluginStep {
    let part = AnyEncodable([
      "type": AnyEncodable("text"), "synthetic": AnyEncodable(true), "text": AnyEncodable("done"),
    ])
    return OpenCodePluginStep(
      hook: "chat.message", input: ["sessionID": session],
      output: ["parts": AnyEncodable([part])])
  }

  static func error(_ session: String, name: String) -> OpenCodePluginStep {
    event(
      "session.error",
      ["sessionID": AnyEncodable(session), "error": AnyEncodable(["name": name])])
  }

  static func tool(session: String) -> OpenCodePluginStep {
    OpenCodePluginStep(hook: "tool.execute.before", input: ["sessionID": session])
  }

  /// Long enough for a lookup the stub answers late to land.
  static var pause: OpenCodePluginStep { OpenCodePluginStep(hook: "pause") }

  static func event(_ type: String, _ properties: [String: AnyEncodable]) -> OpenCodePluginStep {
    OpenCodePluginStep(
      hook: "event", event: ["type": AnyEncodable(type), "properties": AnyEncodable(properties)])
  }

  static func created(child: String, of parent: String, agent: String) -> OpenCodePluginStep {
    event(
      "session.created",
      ["info": AnyEncodable(["id": parent + "/" + child, "parentID": parent, "agent": agent])])
  }

  static func idle(_ session: String) -> OpenCodePluginStep {
    event("session.idle", ["sessionID": AnyEncodable(session)])
  }

  static func busy(_ session: String) -> OpenCodePluginStep {
    event(
      "session.status",
      ["sessionID": AnyEncodable(session), "status": AnyEncodable(["type": "busy"])])
  }

  static func asked(_ session: String, permission: String, pattern: String) -> OpenCodePluginStep {
    event(
      "permission.asked",
      [
        "sessionID": AnyEncodable(session), "permission": AnyEncodable(permission),
        "patterns": AnyEncodable([pattern]),
        "tool": AnyEncodable(["messageID": "message-1", "callID": "call-1"]),
      ])
  }

  static func replied(_ session: String) -> OpenCodePluginStep {
    event("permission.replied", ["sessionID": AnyEncodable(session)])
  }
}
