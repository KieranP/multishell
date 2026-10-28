import Foundation
import MultishellCore
import MultishellProcess

/// Where each integration's tool is on the login shell's PATH.
struct ServiceToolDetection: Equatable, Sendable {
  static let empty = Self(found: [:])

  let found: [ServiceIntegration: URL]

  private init(found: [ServiceIntegration: URL]) {
    self.found = found
  }

  init(searchPath: String?) {
    var found: [ServiceIntegration: URL] = [:]
    for integration in ServiceIntegration.allCases {
      if let executable = ExecutableLookup.find(integration.executableName, searchPath: searchPath)
      {
        found[integration] = executable
      }
    }
    self.found = found
  }

  func isInstalled(_ integration: ServiceIntegration) -> Bool {
    found[integration] != nil
  }
}
