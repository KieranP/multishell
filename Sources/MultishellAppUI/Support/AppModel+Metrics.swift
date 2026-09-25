import MultishellAppCore

extension AppModel {
  var metrics: UIMetrics {
    UIMetrics(fontSize: workspace.appearance.uiFontSize)
  }
}
