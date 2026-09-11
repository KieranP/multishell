import Foundation

/// The built-in themes plus any `*.json` in the themes folder. A user file
/// with a built-in's id replaces it; unreadable ones are skipped.
public struct ThemeCatalog: Sendable {
  public let themes: [Theme]
  public let problems: [String]

  public static func load(from directory: URL = Paths.themesDirectory) -> ThemeCatalog {
    relocateStrayExamples(in: directory)
    var byID = Dictionary(uniqueKeysWithValues: Theme.builtins.map { ($0.id, $0) })
    var problems: [String] = []

    let files =
      (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))
      ?? []
    for file in files where file.pathExtension == "json" {
      do {
        let theme = try JSONDecoder().decode(Theme.self, from: Data(contentsOf: file))
        byID[theme.id] = theme
      } catch {
        problems.append("\(file.lastPathComponent): \(error)")
      }
    }

    let builtinOrder = Theme.builtins.map(\.id)
    let themes = byID.values.sorted { lhs, rhs in
      switch (builtinOrder.firstIndex(of: lhs.id), builtinOrder.firstIndex(of: rhs.id)) {
      case (let l?, let r?): return l < r
      case (.some, nil): return true
      case (nil, .some): return false
      case (nil, nil): return lhs.name < rhs.name
      }
    }
    return ThemeCatalog(themes: themes, problems: problems)
  }

  /// Writes the built-ins out as editable examples, into an `examples/`
  /// subfolder so they are there to copy from but never loaded as themes.
  public static func seedExamples(in directory: URL = Paths.themesDirectory) throws {
    let examples = directory.appendingPathComponent("examples", isDirectory: true)
    try FileManager.default.createDirectory(at: examples, withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    for theme in Theme.builtins {
      let file = examples.appendingPathComponent("\(theme.id).json")
      if !FileManager.default.fileExists(atPath: file.path) {
        try encoder.encode(theme).write(to: file)
      }
    }
  }

  /// An earlier build wrote its examples at the top level, where they loaded
  /// as duplicates. Moves, never deletes; failures let the load go on.
  private static func relocateStrayExamples(in directory: URL) {
    let examples = directory.appendingPathComponent("examples", isDirectory: true)
    for theme in Theme.builtins {
      let stray = directory.appendingPathComponent("example.\(theme.id).json")
      guard FileManager.default.fileExists(atPath: stray.path) else { continue }
      try? FileManager.default.createDirectory(at: examples, withIntermediateDirectories: true)
      let destination = examples.appendingPathComponent(stray.lastPathComponent)
      try? FileManager.default.removeItem(at: destination)
      try? FileManager.default.moveItem(at: stray, to: destination)
    }
  }
}
