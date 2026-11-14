import AppKit
import MultishellAppCore

/// The files of the All changes tab worth highlighting: those a clip either side
/// of the one shown reaches, so a short scroll finds them coloured.
enum AllChangesNearbySections {
  /// Before the view has a size, the first few files, which it opens on.
  private static let unsizedFiles = 8

  static func near(
    _ document: AllChangesDocument,
    geometry: DiffRowGeometry,
    top: CGFloat,
    clipHeight: CGFloat,
  ) -> ClosedRange<Int>? {
    guard clipHeight > 0 else {
      return document.sections.isEmpty ? nil : 0...min(document.sections.count - 1, unsizedFiles)
    }
    let reach = NSRect(x: 0, y: top - clipHeight, width: 1, height: clipHeight * 3)
    return document.sections(reaching: geometry.rows(in: reach, count: document.text.lines.count))
  }
}
