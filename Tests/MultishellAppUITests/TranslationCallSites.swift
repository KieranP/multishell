import Foundation
import Testing

/// Every `t("key", ...)` call in the app's sources, read off the checkout.
enum TranslationCallSites {
  struct CallSite {
    let key: String
    let arguments: Int
    let `where`: String
  }

  /// Arguments are counted by walking the brackets rather than by pattern, since an argument
  /// is as often a call as a name.
  static func all() throws -> [CallSite] {
    var sites: [CallSite] = []
    for file in try swiftFiles() {
      let text = try String(contentsOf: file, encoding: .utf8)
      for match in text.matches(of: /\bt\(\s*"([^"]+)"/) {
        sites.append(
          CallSite(
            key: String(match.output.1),
            arguments: arguments(in: text, from: match.range.upperBound),
            where: file.lastPathComponent))
      }
    }
    #expect(sites.count > 100, "the source scan found almost nothing; is the path still right?")
    return sites
  }

  /// Commas at the call's own bracket depth, after the key. Text in a
  /// string literal is skipped, a comma inside one being no argument.
  private static func arguments(in text: String, from start: String.Index) -> Int {
    var depth = 1
    var count = 0
    var index = start
    while index < text.endIndex, depth > 0 {
      switch text[index] {
      case "(", "[", "{": depth += 1
      case ")", "]", "}": depth -= 1
      case "," where depth == 1: count += 1
      case "\"":
        index = text.index(after: index)
        while index < text.endIndex, text[index] != "\"" {
          if text[index] == "\\" { index = text.index(after: index) }
          index = text.index(after: index)
        }
      default: break
      }
      index = text.index(after: index)
    }
    return count
  }

  static func swiftFiles() throws -> [URL] {
    let start = Checkout.root.appendingPathComponent("Sources/MultishellAppUI")
    let walk = FileManager.default.enumerator(at: start, includingPropertiesForKeys: nil)
    return (walk?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
  }

  static func placeholders(in english: String) -> [String] {
    let all = english.matches(of: /%[0-9]*\$?[0-9.]*[@dfs]/).map { String($0.output) }
    let numbered = Set(all.filter { $0.contains("$") }.map { $0.prefix { $0 != "$" } })
    return numbered.isEmpty ? all : Array(repeating: "%1$@", count: numbered.count)
  }
}
