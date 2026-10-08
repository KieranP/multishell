import Foundation

/// Every `t("key", ...)` call in one half's sources, read off the checkout.
public enum TranslationCallSites {
  public struct CallSite: Sendable {
    public let key: String
    public let argumentCount: Int
    public let fileName: String
  }

  public static var appSwiftFiles: [URL] { swiftFiles(under: "Sources/MultishellAppUI") }

  /// Not the app's target, whose `t` answers from a catalogue of its own.
  public static var librarySwiftFiles: [URL] {
    swiftFiles(under: "Sources", excluding: "Sources/MultishellAppUI")
  }

  /// Arguments are counted by walking the brackets rather than by pattern, since an argument
  /// is as often a call as a name.
  public static func all(in files: [URL]) throws -> [CallSite] {
    var sites: [CallSite] = []
    for file in files {
      let text = try String(contentsOf: file, encoding: .utf8)
      for match in text.matches(of: /\bt\(\s*"([^"]+)"/) {
        sites.append(
          CallSite(
            key: String(match.output.1),
            argumentCount: argumentCount(in: text, from: match.range.upperBound),
            fileName: file.lastPathComponent))
      }
    }
    guard sites.count > 100 else { throw TranslationScanFoundNothing(count: sites.count) }
    return sites
  }

  /// Commas at the call's own bracket depth, after the key. Text in a
  /// string literal is skipped, a comma inside one being no argument.
  private static func argumentCount(in text: String, from start: String.Index) -> Int {
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

  private static func swiftFiles(under folder: String, excluding excluded: String? = nil) -> [URL] {
    let start = SourceRoot.url.appendingPathComponent(folder)
    let skipped = excluded.map { SourceRoot.url.appendingPathComponent($0).path + "/" }
    let walk = FileManager.default.enumerator(at: start, includingPropertiesForKeys: nil)
    return (walk?.allObjects as? [URL] ?? []).filter { file in
      file.pathExtension == "swift" && !(skipped.map(file.path.hasPrefix) ?? false)
    }
  }
}
