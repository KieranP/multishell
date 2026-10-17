import MultishellAppCore
import MultishellCore

extension AppModel {
  var metrics: UIMetrics {
    UIMetrics(
      fontSize: workspace.appearance.uiFontSize,
      fontFamily: workspace.appearance.uiFontName,
    )
  }
}
