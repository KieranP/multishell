import Foundation

/// The repository these tests were built from, for files SwiftPM never copies.
public enum SourceRoot {
  public static let url = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // TestScratch
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()
}
