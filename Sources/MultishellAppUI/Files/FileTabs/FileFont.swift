/// A file tab's font as Settings > Appearance sets it; the rows' geometry is
/// built from it, so a change rebuilds the view.
struct FileFont: Hashable {
  /// `nil` is the system monospace.
  let family: String?
  let size: Double
}
