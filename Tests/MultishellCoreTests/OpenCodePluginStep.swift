/// A step handed to the driver: a hook by name with what OpenCode passes it,
/// or an event off the bus.
struct OpenCodePluginStep: Encodable {
  /// Lets every lookup the stub answers late land.
  static var answerLateLookups: Self { Self(hook: "answerLateLookups") }

  var hook: String
  var input: [String: AnyEncodable]?
  var event: [String: AnyEncodable]?
  /// A hook the driver calls without waiting for, so the next step runs during it.
  var isUnawaited = false

  static func message(session: String?) -> Self {
    guard let session else { return Self(hook: "prompt", input: [:]) }
    return Self(
      hook: "prompt",
      input: [
        "sessionID": AnyEncodable(session), "prompt": AnyEncodable(["text": "go"]),
        "delivery": AnyEncodable("steer"),
      ],
    )
  }

  static func tool(session: String) -> Self {
    Self(
      hook: "execute.before",
      input: ["sessionID": AnyEncodable(session), "tool": AnyEncodable("bash")],
    )
  }

  static func event(_ type: String, _ data: [String: AnyEncodable]) -> Self {
    Self(hook: "event", event: ["type": AnyEncodable(type), "data": AnyEncodable(data)])
  }

  /// A child's creation; `directory` nil leaves its location out.
  static func created(
    child: String,
    of parent: String,
    agent: String,
    directory: String? = "/w",
  ) -> Self {
    var data = [
      "sessionID": AnyEncodable(parent + "/" + child), "parentID": AnyEncodable(parent),
      "agent": AnyEncodable(agent),
    ]
    if let directory { data["location"] = AnyEncodable(["directory": directory]) }
    return event("session.created", data)
  }

  /// A top-level session's creation; `directory` nil leaves its location out.
  static func created(_ session: String, directory: String?) -> Self {
    var data = ["sessionID": AnyEncodable(session), "agent": AnyEncodable("build")]
    if let directory { data["location"] = AnyEncodable(["directory": directory]) }
    return event("session.created", data)
  }

  /// `count` top-level sessions created in `directory`, pushing older ones out
  /// of the plugin's bounds.
  static func sessionsCreated(in directory: String, count: Int) -> [Self] {
    (0..<count).map { created("s\($0)", directory: directory) }
  }

  /// `count` children of `parent` that start and end, pushing older ones out of
  /// the ended children the plugin keeps.
  static func endedChildren(of parent: String, count: Int) -> [Self] {
    (0..<count).flatMap { index in
      [
        created(child: "e\(index)", of: parent, agent: "Explore"), succeeded("\(parent)/e\(index)"),
      ]
    }
  }

  /// The TUI's move of a session to another worktree.
  static func moved(_ session: String, to directory: String) -> Self {
    event(
      "session.moved",
      ["sessionID": AnyEncodable(session), "location": AnyEncodable(["directory": directory])],
    )
  }

  static func started(_ session: String) -> Self {
    event("session.execution.started", ["sessionID": AnyEncodable(session)])
  }

  static func succeeded(_ session: String) -> Self {
    event("session.execution.succeeded", ["sessionID": AnyEncodable(session)])
  }

  static func failed(_ session: String) -> Self {
    event(
      "session.execution.failed",
      [
        "sessionID": AnyEncodable(session),
        "error": AnyEncodable(["type": "provider.auth", "message": "expired"]),
      ],
    )
  }

  static func interrupted(_ session: String, reason: String) -> Self {
    event(
      "session.execution.interrupted",
      ["sessionID": AnyEncodable(session), "reason": AnyEncodable(reason)],
    )
  }

  static func asked(_ session: String, action: String, resource: String) -> Self {
    event(
      "permission.asked",
      [
        "id": AnyEncodable("per_1"), "sessionID": AnyEncodable(session),
        "action": AnyEncodable(action), "resources": AnyEncodable([resource]),
        "source": AnyEncodable(["type": "tool", "messageID": "msg_1", "id": "call_1"]),
      ],
    )
  }

  static func replied(_ session: String) -> Self {
    event(
      "permission.replied",
      [
        "sessionID": AnyEncodable(session), "requestID": AnyEncodable("per_1"),
        "reply": AnyEncodable("once"),
      ],
    )
  }

  func unawaited() -> Self {
    var step = self
    step.isUnawaited = true
    return step
  }

  /// The same event with its envelope naming the directory it belongs to.
  func located(in directory: String) -> Self {
    var located = self
    located.event?["location"] = AnyEncodable(["directory": directory])
    return located
  }

  /// The same event with an envelope location that names no directory.
  func locatedNowhere() -> Self {
    var located = self
    located.event?["location"] = AnyEncodable([String: String]())
    return located
  }
}
