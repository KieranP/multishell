import Foundation

/// What AppleScript reported, as the alert shows it.
struct AppleScriptFailed: Error, CustomStringConvertible {
  let message: String

  var description: String { message }

  init(message: String) {
    self.message = message
  }

  init(_ problem: NSDictionary?) {
    message = problem?[NSAppleScript.errorMessage] as? String ?? "\(problem ?? [:])"
  }
}
