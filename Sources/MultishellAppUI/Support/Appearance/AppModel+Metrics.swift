import MultishellAppCore
import MultishellCore

extension AppModel {
  var metrics: UIMetrics {
    UIMetrics(fontSize: workspace.appearance.uiFontSize)
  }
}
