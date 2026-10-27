import Foundation

/// Parses `git remote -v`: a name, a tab, the URL, then `(fetch)` or `(push)`,
/// and a partial clone's ` [blob:none]` after it. Each remote once, in order.
enum GitRemoteParser {
  private enum Direction: String {
    case fetch = " (fetch)"
    case push = " (push)"
  }

  static func parse(_ output: String) -> [GitRemote] {
    var names: [String] = []
    var fetchURLs: [String: String] = [:]
    var pushURLs: [String: String] = [:]
    for line in output.split(whereSeparator: \.isNewline) {
      guard let (name, url, direction) = entry(line) else { continue }
      switch direction {
      case .fetch:
        if fetchURLs[name] == nil { names.append(name) }
        fetchURLs[name] = url

      case .push:
        pushURLs[name] = url
      }
    }
    return names.compactMap { name in
      fetchURLs[name].map { url in
        // Only a push URL that differs says something: git lists the fetch one twice.
        let pushURL = pushURLs[name].flatMap { $0 == url ? nil : $0 }
        return GitRemote(name: name, url: url, pushURL: pushURL)
      }
    }
  }

  private static func entry(_ line: Substring) -> (String, String, Direction)? {
    let fields = line.split(separator: "\t", maxSplits: 1)
    guard fields.count == 2, !fields[0].isEmpty else { return nil }
    for direction in [Direction.fetch, .push] {
      guard let end = fields[1].range(of: direction.rawValue, options: .backwards),
        end.upperBound == fields[1].endIndex || fields[1][end.upperBound...].hasPrefix(" [")
      else { continue }
      let url = fields[1][..<end.lowerBound]
      return url.isEmpty ? nil : (String(fields[0]), String(url), direction)
    }
    return nil
  }
}
