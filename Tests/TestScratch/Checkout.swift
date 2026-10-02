import Foundation

/// The repository these tests were built from, for files SwiftPM never copies.
public enum Checkout {
  public static let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // TestScratch
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()
}
