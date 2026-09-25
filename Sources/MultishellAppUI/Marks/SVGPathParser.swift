import SwiftUI

/// Reads the one path out of a mark's `.svg`: absolute `M`, `L`, `C`, `Q` and
/// `Z` alone, anything else refused. See Docs/design/agents.md.
enum SVGPathParser {
  static func path(fromSVG text: String) -> Path? {
    guard let d = attribute("d", in: text) else { return nil }
    return path(fromData: d)
  }

  static func path(fromData d: String) -> Path? {
    var path = Path()
    var numbers: [Double] = []
    var command: Character?
    var drew = false

    func flush() -> Bool {
      guard let command else { return numbers.isEmpty }
      let arity: Int
      switch command {
      case "M", "L": arity = 2
      case "Q": arity = 4
      case "C": arity = 6
      case "Z": arity = 0
      default: return false
      }
      if command == "Z" {
        guard numbers.isEmpty else { return false }
        path.closeSubpath()
        return true
      }
      guard !numbers.isEmpty, numbers.count % arity == 0 else { return false }
      for start in stride(from: 0, to: numbers.count, by: arity) {
        let v = Array(numbers[start..<start + arity])
        switch command {
        // Pairs after a move are lines, which is how a polygon is written.
        case "M" where start == 0: path.move(to: CGPoint(x: v[0], y: v[1]))
        case "M", "L": path.addLine(to: CGPoint(x: v[0], y: v[1]))
        case "Q":
          path.addQuadCurve(
            to: CGPoint(x: v[2], y: v[3]), control: CGPoint(x: v[0], y: v[1]))
        default:
          path.addCurve(
            to: CGPoint(x: v[4], y: v[5]), control1: CGPoint(x: v[0], y: v[1]),
            control2: CGPoint(x: v[2], y: v[3]))
        }
        drew = true
      }
      numbers.removeAll(keepingCapacity: true)
      return true
    }

    var number = ""
    func takeNumber() -> Bool {
      guard !number.isEmpty else { return true }
      guard let value = Double(number) else { return false }
      numbers.append(value)
      number.removeAll(keepingCapacity: true)
      return true
    }

    for character in d {
      if character.isNumber || character == "." {
        number.append(character)
      } else if character == "-" {
        // A minus starts the next number unless it is the exponent's.
        if number.isEmpty || number.hasSuffix("e") || number.hasSuffix("E") {
          number.append(character)
        } else {
          guard takeNumber() else { return nil }
          number.append(character)
        }
      } else if character == "e" || character == "E" {
        guard !number.isEmpty else { return nil }
        number.append(character)
      } else if character.isWhitespace || character == "," {
        guard takeNumber() else { return nil }
      } else {
        guard takeNumber(), flush() else { return nil }
        command = character
      }
    }
    guard takeNumber(), flush(), drew else { return nil }
    return path
  }

  /// The whole attribute and not the end of another: `id="…"` holds a `d="`,
  /// and reading its value as path data draws nothing.
  private static func attribute(_ name: String, in text: String) -> String? {
    var from = text.startIndex
    while let opening = text.range(of: "\(name)=\"", range: from..<text.endIndex) {
      from = opening.upperBound
      let before = opening.lowerBound
      if before == text.startIndex || !text[text.index(before: before)].isNameCharacter {
        guard let closing = text[from...].firstIndex(of: "\"") else { return nil }
        return String(text[from..<closing])
      }
    }
    return nil
  }
}

extension Character {
  fileprivate var isNameCharacter: Bool { isLetter || isNumber || self == "-" || self == "_" }
}
