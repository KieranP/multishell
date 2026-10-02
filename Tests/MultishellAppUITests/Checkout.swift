import Foundation

/// The repository these tests were built from, for files SwiftPM never copies.
enum Checkout {
  static let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // MultishellAppUITests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()
}
