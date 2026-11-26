import Foundation

extension TestGit {
  /// Whether the git on PATH has `git refs migrate`, 2.46 and later; a test that
  /// builds a reftable repository with it is skipped on an older one.
  public static let migratesRefs: Bool = {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git", "version"]
    process.standardOutput = pipe
    guard (try? process.run()) != nil else { return false }
    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    process.waitUntilExit()
    let numbers =
      output.split(separator: " ").dropFirst(2).first?.split(separator: ".")
      .compactMap { Int($0) } ?? []
    guard numbers.count >= 2 else { return false }
    return (numbers[0], numbers[1]) >= (2, 46)
  }()
}
