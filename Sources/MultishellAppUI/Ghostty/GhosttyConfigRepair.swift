import GhosttyTerminal

/// Blanks the lines libghostty complains of, so one bad line in the user's
/// config does not cost them the rest of it.
enum GhosttyConfigRepair {
  private static let maximumPasses = 3

  /// libghostty refuses a file whole over one complaint, where Ghostty names
  /// the line and carries on. Blank the named lines and offer the rest again.
  @MainActor
  static func repair(_ controller: TerminalController, base: String) {
    var lines = base.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    for _ in 0..<maximumPasses {
      guard let issue = controller.lastConfigurationIssue else { return }
      let refused = refusedLines(in: issue).filter { $0 >= 1 && $0 <= lines.count }
      guard !refused.isEmpty else { break }
      // Blanked rather than removed, so the next pass's line numbers are
      // this pass's.
      for number in refused { lines[number - 1] = "" }
      controller.updateConfigSource(.generated(lines.joined(separator: "\n")))
    }
    guard controller.lastConfigurationIssue != nil else { return }
    controller.updateConfigSource(.generated(GhosttyUserConfig.defaults.rendered))
  }

  /// Diagnostics arrive as one `" | "`-joined string. Only that text says
  /// which line, so a reworded wrapper costs the repair, not the terminal.
  private static func refusedLines(in issue: String) -> [Int] {
    issue.components(separatedBy: " | ").compactMap { part in
      guard let range = part.range(of: #"\.conf:\d+:"#, options: .regularExpression) else {
        return nil
      }
      return Int(part[range].dropFirst(6).dropLast())
    }
  }
}
