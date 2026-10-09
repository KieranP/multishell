import SwiftUI

/// Reads the one path out of a mark's `.svg`: absolute `M`, `L`, `C`, `Q` and
/// `Z` alone, anything else refused. See Docs/design/agents.md.
enum SVGPathParser {
  static func path(fromSVG text: String) -> Path? {
    guard let pathData = attribute("d", in: text) else { return nil }
    return path(fromData: pathData)
  }

  // One pass over the path data, kept whole by choice; Docs/develop/build.md.
  // swiftlint:disable:next function_body_length
  static func path(fromData pathData: String) -> Path? {
    var path = Path()
    var numbers: [Double] = []
    var command: Character?
    var hasDrawn = false

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
      guard !numbers.isEmpty, numbers.count.isMultiple(of: arity) else { return false }
      for start in stride(from: 0, to: numbers.count, by: arity) {
        let values = Array(numbers[start..<start + arity])
        switch command {
        // Pairs after a move are lines, which is how a polygon is written.
        case "M" where start == 0: path.move(to: CGPoint(x: values[0], y: values[1]))
        case "M", "L": path.addLine(to: CGPoint(x: values[0], y: values[1]))

        case "Q":
          path.addQuadCurve(
            to: CGPoint(x: values[2], y: values[3]),
            control: CGPoint(x: values[0], y: values[1]),
          )

        default:
          path.addCurve(
            to: CGPoint(x: values[4], y: values[5]),
            control1: CGPoint(x: values[0], y: values[1]),
            control2: CGPoint(x: values[2], y: values[3]),
          )
        }
        hasDrawn = true
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

    for character in pathData {
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
    guard takeNumber(), flush(), hasDrawn else { return nil }
    return path
  }

  /// The whole attribute and not the end of another: `id="…"` holds a `d="`,
  /// and reading its value as path data draws nothing.
  private static func attribute(_ name: String, in text: String) -> String? {
    var from = text.startIndex
    while let opening = text.range(of: "\(name)=\"", range: from..<text.endIndex) {
      from = opening.upperBound
      let before = opening.lowerBound
      if before == text.startIndex || !isNameCharacter(text[text.index(before: before)]) {
        guard let closing = text[from...].firstIndex(of: "\"") else { return nil }
        return String(text[from..<closing])
      }
    }
    return nil
  }

  private static func isNameCharacter(_ character: Character) -> Bool {
    character.isLetter || character.isNumber || character == "-" || character == "_"
  }
}
