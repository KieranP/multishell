import Foundation

extension URL {
  /// Stats the path, so not on the main actor. A path the volume will not
  /// answer for counts as local.
  var isOnLocalVolume: Bool {
    (try? resourceValues(forKeys: [.volumeIsLocalKey]).volumeIsLocal) ?? true
  }
}
