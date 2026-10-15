import GhosttyKit

extension GhosttySurfaceView {
  /// Under libghostty's renderer lock: the live screen, not the viewport a
  /// scroll moves, or every line kept. `nil` once freed.
  func text(includingScrollback: Bool) -> String? {
    guard let surface else { return nil }
    let region = includingScrollback ? GHOSTTY_POINT_SCREEN : GHOSTTY_POINT_ACTIVE
    let selection = ghostty_selection_s(
      top_left: ghostty_point_s(tag: region, coord: GHOSTTY_POINT_COORD_TOP_LEFT, x: 0, y: 0),
      bottom_right: ghostty_point_s(
        tag: region,
        coord: GHOSTTY_POINT_COORD_BOTTOM_RIGHT,
        x: 0,
        y: 0,
      ),
      rectangle: false,
    )
    // A blank screen dumps nothing, which reads as a failure.
    return readText(from: surface) { ghostty_surface_read_text(surface, selection, &$0) } ?? ""
  }

  /// `nil` with nothing selected, or once freed.
  func selectionText() -> String? {
    guard let surface else { return nil }
    return readText(from: surface) { ghostty_surface_read_selection(surface, &$0) }
  }

  /// `nil` where libghostty read nothing.
  private func readText(
    from surface: ghostty_surface_t,
    _ fill: (inout ghostty_text_s) -> Bool,
  ) -> String? {
    var text = ghostty_text_s()
    guard fill(&text) else { return nil }
    defer { ghostty_surface_free_text(surface, &text) }
    guard let bytes = text.text else { return nil }
    return String(
      decoding: UnsafeRawBufferPointer(start: bytes, count: Int(text.text_len)),
      as: UTF8.self,
    )
  }
}
