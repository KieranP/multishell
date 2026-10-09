/// A step handed to the driver: a hook by name, with whatever OpenCode
/// passes it.
struct OpenCodePluginStep: Encodable {
  /// Long enough for a lookup the stub answers late to land.
  static var pause: Self { Self(hook: "pause") }

  var hook: String
  var input: [String: String]?
  var output: [String: AnyEncodable]?
  var event: [String: AnyEncodable]?

  static func message(session: String?, inSecondArgument: Bool = false) -> Self {
    guard let session else { return Self(hook: "chat.message", input: [:]) }
    return inSecondArgument
      ? Self(
        hook: "chat.message",
        input: [:],
        output: ["message": AnyEncodable(["sessionID": session])],
      )
      : Self(hook: "chat.message", input: ["sessionID": session])
  }

  /// The prompt OpenCode sends itself when a background child ends.
  static func synthetic(session: String) -> Self {
    let part = AnyEncodable([
      "type": AnyEncodable("text"), "synthetic": AnyEncodable(true), "text": AnyEncodable("done"),
    ])
    return Self(
      hook: "chat.message",
      input: ["sessionID": session],
      output: ["parts": AnyEncodable([part])],
    )
  }

  static func error(_ session: String, name: String) -> Self {
    event(
      "session.error",
      ["sessionID": AnyEncodable(session), "error": AnyEncodable(["name": name])],
    )
  }

  static func tool(session: String) -> Self {
    Self(hook: "tool.execute.before", input: ["sessionID": session])
  }

  static func event(_ type: String, _ properties: [String: AnyEncodable]) -> Self {
    Self(
      hook: "event",
      event: ["type": AnyEncodable(type), "properties": AnyEncodable(properties)],
    )
  }

  static func created(child: String, of parent: String, agent: String) -> Self {
    event(
      "session.created",
      ["info": AnyEncodable(["id": parent + "/" + child, "parentID": parent, "agent": agent])],
    )
  }

  static func idle(_ session: String) -> Self {
    event("session.idle", ["sessionID": AnyEncodable(session)])
  }

  static func busy(_ session: String) -> Self {
    event(
      "session.status",
      ["sessionID": AnyEncodable(session), "status": AnyEncodable(["type": "busy"])],
    )
  }

  static func asked(_ session: String, permission: String, pattern: String) -> Self {
    event(
      "permission.asked",
      [
        "sessionID": AnyEncodable(session), "permission": AnyEncodable(permission),
        "patterns": AnyEncodable([pattern]),
        "tool": AnyEncodable(["messageID": "message-1", "callID": "call-1"]),
      ],
    )
  }

  static func replied(_ session: String) -> Self {
    event("permission.replied", ["sessionID": AnyEncodable(session)])
  }
}
