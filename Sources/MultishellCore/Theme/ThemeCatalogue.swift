import Foundation

/// The built-in themes plus any `*.json` in the themes folder, listed by name. A
/// user file with a built-in's id replaces it; unreadable ones are skipped.
public struct ThemeCatalogue: Sendable {
  public static let builtinsOnly = Self(themes: byName(Theme.builtins), problems: [])

  public let themes: [Theme]
  public let problems: [ThemeFileProblem]

  /// Examples an earlier build wrote under another name are removed first: they
  /// are flat files no build now loads, and would read as broken themes.
  public static func loadRemovingStrayExamples(from directory: URL) -> Self {
    removeStrayExamples(in: directory)
    var byID = Theme.builtins.keyedByID()
    var problems: [ThemeFileProblem] = []

    let files =
      (try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        // An editor's lock or swap file, such as Emacs's `.#mine.json`, is no theme.
        options: .skipsHiddenFiles,
      )) ?? []
    for file in files where file.pathExtension == "json" {
      do {
        let theme = try JSONDecoder().decode(Theme.self, from: Data(contentsOf: file))
        byID[theme.id] = theme
      } catch {
        problems.append(ThemeFileProblem(fileName: file.lastPathComponent, reason: "\(error)"))
      }
    }

    return Self(themes: byName(byID.values), problems: problems)
  }

  /// As Finder orders names: case aside, and `Theme 2` before `Theme 10`.
  private static func byName(_ themes: some Sequence<Theme>) -> [Theme] {
    themes.sorted { lhs, rhs in
      switch lhs.name.localizedStandardCompare(rhs.name) {
      case .orderedAscending: true
      case .orderedDescending: false
      case .orderedSame: lhs.id < rhs.id
      }
    }
  }

  /// Copies every built-in theme into `examples/`, to copy from but never loaded.
  /// One that differs is rewritten, a stale example hiding keys.
  public static func seedExamples(in directory: URL) throws {
    let examples = examplesDirectory(in: directory)
    for theme in Theme.builtins {
      guard let source = Theme.builtinFile(named: theme.id) else { continue }
      let contents = try Data(contentsOf: source)
      let file = examples.appendingPathComponent("\(theme.id).json")
      if (try? Data(contentsOf: file)) != contents {
        try contents.writeAtomicallyCreatingDirectory(to: file)
      }
    }
  }

  /// Both places an earlier build left them; failures let the load go on.
  private static func removeStrayExamples(in directory: URL) {
    for theme in [Theme.multishellDark, .multishellLight] {
      let name = "example.\(theme.id).json"
      for place in [directory, examplesDirectory(in: directory)] {
        try? FileManager.default.removeItem(at: place.appendingPathComponent(name))
      }
    }
  }

  private static func examplesDirectory(in directory: URL) -> URL {
    directory.appendingPathComponent("examples", isDirectory: true)
  }
}
