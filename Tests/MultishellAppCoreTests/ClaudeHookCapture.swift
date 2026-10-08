import Foundation

/// The hooks Claude Code 2.1.292 sent in five runs, trimmed to the fields read,
/// and each worker's `meta.json`, from `Fixtures/ClaudeHookCaptures`.
enum ClaudeHookCapture {
  static let fanOut = payloads("fan-out")
  static let killsAndChains = payloads("kills-and-chains")
  static let killedParent = payloads("killed-parent")
  static let killedMiddle = payloads("killed-middle")
  static let mainInterrupted = payloads("main-interrupted")

  static let workerMetadata: [String: String] = {
    let data = try! Data(contentsOf: fixture("worker-metadata.json"))
    let objects = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    return objects.mapValues { object in
      String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }
  }()

  private static func payloads(_ name: String) -> [String] {
    let text = try! String(contentsOf: fixture("\(name).jsonl"), encoding: .utf8)
    return text.split(separator: "\n").map(String.init)
  }

  private static func fixture(_ file: String) -> URL {
    Bundle.module.resourceURL!.appendingPathComponent("Fixtures/ClaudeHookCaptures/\(file)")
  }
}
