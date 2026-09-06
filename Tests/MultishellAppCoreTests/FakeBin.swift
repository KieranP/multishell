import Foundation

/// A temp directory of fake executables, for detection on a fake PATH.
func fakeBin(_ names: [String]) throws -> URL {
  let directory = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("multishell-bin-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  for name in names {
    let file = directory.appendingPathComponent(name)
    try "#!/bin/sh\nexit 0\n".write(to: file, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
  }
  return directory
}
