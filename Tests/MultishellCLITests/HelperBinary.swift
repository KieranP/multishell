import Foundation

/// The helper product, built beside the test bundle whatever the
/// configuration or scratch path; the test target depends on it.
enum HelperBinary {
  static let url: URL = {
    let products = Bundle.allBundles.first { $0.bundleURL.pathExtension == "xctest" }?
      .bundleURL.deletingLastPathComponent()
    return (products ?? URL(fileURLWithPath: ".build/debug")).appendingPathComponent("multishell")
  }()

  /// Named here rather than found out from a launch error in every test.
  static func require() throws -> URL {
    guard FileManager.default.isExecutableFile(atPath: url.path) else {
      throw Missing(path: url.path)
    }
    return url
  }

  struct Missing: Error, CustomStringConvertible {
    let path: String
    var description: String {
      "no helper beside the test bundle at \(path); is MultishellCLI built?"
    }
  }
}
