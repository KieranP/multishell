import Foundation

/// Parses `git rev-list --count`: one number and a newline. `nil` for anything else.
enum RevListCountParser {
  static func parse(_ output: String) -> Int? {
    Int(output.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}
