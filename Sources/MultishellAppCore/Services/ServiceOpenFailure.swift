import MultishellCore

/// A service's tool that failed to open a page in the browser.
struct ServiceOpenFailure: Error {
  let integration: ServiceIntegration
  let underlying: any Error
}
