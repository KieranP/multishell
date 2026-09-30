import Foundation

/// Node as OpenCodePluginTests' trait reads it, before the suite exists.
let openCodeNode: URL? = {
  let fixed = ["/usr/local/bin/node", "/opt/homebrew/bin/node", "/usr/bin/node"]
  let path = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":") ?? []
  return (fixed + path.map { "\($0)/node" })
    .map(URL.init(fileURLWithPath:))
    .first { FileManager.default.isExecutableFile(atPath: $0.path) }
}()
