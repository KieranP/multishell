import Foundation

extension Harness {
  /// The files the comments waiting to be sent are kept in, by name.
  var reviewFileNames: [String] {
    (try? FileManager.default.contentsOfDirectory(atPath: reviews.path)) ?? []
  }
}
