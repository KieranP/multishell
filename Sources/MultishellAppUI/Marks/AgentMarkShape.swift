import MultishellCore
import SwiftUI

/// One agent's mark, read from its `.svg` in `Resources/Marks` and scaled
/// from its 16-point square; see Docs/design/agents.md.
struct AgentMarkShape: Shape {
  /// Parsed once, on the first mark drawn: every row reads a path each render, and a `let`
  /// needs no lock. A bad or missing file draws nothing; `AgentMarkShapeTests` catches it.
  private static let paths: [String: Path] = {
    var parsed: [String: Path] = [:]
    for name in AgentMark.drawn.compactMap(resourceName(of:)) {
      guard let url = Bundle.module.url(forResource: name, withExtension: "svg"),
        let text = try? String(contentsOf: url, encoding: .utf8),
        let path = SVGPathParser.path(fromSVG: text)
      else { continue }
      parsed[name] = path
    }
    return parsed
  }()

  let mark: AgentMark

  /// The file name in `Resources/Marks`. A mark with no file draws nothing.
  static func resourceName(of mark: AgentMark) -> String? {
    switch mark {
    case .claude: "claude"
    case .codex: "codex"
    case .copilot: "copilot"
    case .openCode: "opencode"
    case .gemini: "gemini"
    case .monogram: nil
    }
  }

  static func unitPath(of mark: AgentMark) -> Path? {
    resourceName(of: mark).flatMap { paths[$0] }
  }

  func path(in rect: CGRect) -> Path {
    guard let unit = Self.unitPath(of: mark) else { return Path() }
    let side = min(rect.width, rect.height)
    let scale = side / 16
    let transform = CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2)
      .scaledBy(x: scale, y: scale)
    return unit.applying(transform)
  }
}
