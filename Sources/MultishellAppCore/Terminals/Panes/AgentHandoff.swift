import Foundation
import MultishellCore

/// A note too long to paste, written to the drops directory for an agent to read:
/// Claude Code folds a long paste. See terminals/paste-and-drop.md.
enum AgentHandoff {
  /// Markdown, each entry under a heading. Code is indented rather than fenced,
  /// so a quoted line holding a fence cannot end the block.
  static func document(introduction: String, entries: [AgentHandoffEntry]) -> String {
    var document = introduction + "\n"
    for entry in entries {
      document += "\n## \(entry.heading)\n"
      if let caveat = entry.caveat { document += "\n\(caveat)\n" }
      if !entry.quote.isEmpty {
        document += "\n" + entry.quote.map { "    " + $0 }.joined(separator: "\n") + "\n"
      }
      document += "\n\(entry.text)\n"
    }
    return document
  }

  /// In a directory of its own, dated for the sweep, so the name needs no counter.
  static func write(_ document: String, named name: String, in parent: URL) throws -> URL {
    let directory = try DropCopies.makeDirectory(in: parent)
    let file = directory.appendingPathComponent(name, isDirectory: false)
    do {
      try Data(document.utf8).write(to: file, options: .atomic)
    } catch {
      DropCopies.remove(directory)
      throw error
    }
    DropCopies.keep(directory)
    return file
  }
}
