/// A file tab's font as Settings > Appearance sets it; the rows' geometry is
/// built from it, so a change rebuilds the view.
public struct FileFont: Hashable {
  /// `nil` is the system monospace.
  public let family: String?
  public let size: Double
}
