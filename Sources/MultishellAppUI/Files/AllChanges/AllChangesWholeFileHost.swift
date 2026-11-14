import MultishellAppCore
import MultishellCore

/// What a whole file's view in Split is drawn and acted through.
@MainActor
struct AllChangesWholeFileHost {
  let model: AppModel
  let tab: AllChangesTab
  let theme: Theme
  /// The columns', so its rows are theirs in font and height.
  let geometry: DiffRowGeometry
}
