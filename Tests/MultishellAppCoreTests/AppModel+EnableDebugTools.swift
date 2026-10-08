@testable import MultishellAppCore

extension AppModel {
  /// Debug tools on with a scan of the test's own and no sampling tick to
  /// race it: each test takes its samples itself.
  func enableDebugTools(scan: DebugProcessScan = .sample(appMemory: 400, trees: [])) {
    debugSampler.interval = .seconds(3_600)
    debugSampler.scanProcesses = { _, _ in scan }
    setDebugToolsEnabled(true)
  }
}
