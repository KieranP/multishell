import Foundation

/// The built-in themes plus any `*.json` in the themes folder. A user file
/// with a built-in's id replaces it; unreadable ones are skipped.
public struct ThemeCatalogue: Sendable {
  public let themes: [Theme]
  public let problems: [String]

  /// Strays an earlier build left at the top level are moved first, or they
  /// would load as duplicates.
  public static func loadMovingStrayExamples(
    from directory: URL = Paths.themesDirectory
  ) -> ThemeCatalogue {
    moveStrayExamples(in: directory)
    var byID = Theme.builtins.keyedByID()
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
      case (let lhsIndex?, let rhsIndex?): return lhsIndex < rhsIndex
      case (.some, nil): return true
      case (nil, .some): return false
      case (nil, nil): return lhs.name < rhs.name
      }
    }
    return ThemeCatalogue(themes: themes, problems: problems)
  }

  /// Writes the built-ins out as editable examples, into an `examples/`
  /// subfolder so they are there to copy from but never loaded as themes.
  public static func seedExamples(in directory: URL = Paths.themesDirectory) throws {
    let examples = examplesDirectory(in: directory)
    let encoder = JSONEncoder.forFile()
    for theme in Theme.builtins {
      let file = examples.appendingPathComponent("\(theme.id).json")
      if !FileManager.default.fileExists(atPath: file.path) {
        try encoder.encode(theme).writeAtomicallyCreatingDirectory(to: file)
      }
    }
  }

  /// Replaces an example of the same name already in `examples/`; failures
  /// let the load go on.
  private static func moveStrayExamples(in directory: URL) {
    let examples = examplesDirectory(in: directory)
    for theme in Theme.builtins {
      let stray = directory.appendingPathComponent("example.\(theme.id).json")
      guard FileManager.default.fileExists(atPath: stray.path) else { continue }
      try? FileManager.default.createDirectory(at: examples, withIntermediateDirectories: true)
      let destination = examples.appendingPathComponent(stray.lastPathComponent)
      try? FileManager.default.removeItem(at: destination)
      try? FileManager.default.moveItem(at: stray, to: destination)
    }
  }

  private static func examplesDirectory(in directory: URL) -> URL {
    directory.appendingPathComponent("examples", isDirectory: true)
  }
}
