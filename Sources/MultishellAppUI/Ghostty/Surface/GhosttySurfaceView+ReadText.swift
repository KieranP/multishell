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
    return readText(from: surface) { ghostty_surface_read_text(surface, selection, &$0) }?.text
      ?? ""
  }

  /// `nil` with nothing selected, or once freed.
  func selectionText() -> String? {
    guard let surface else { return nil }
    return readText(from: surface) { ghostty_surface_read_selection(surface, &$0) }?.text
  }

  /// The word a double-click would pick under the pointer, with the viewport
  /// row and column it starts at; `nil` over nothing, or once freed.
  func wordUnderPointer() -> (text: String, row: Int, column: Int)? {
    guard let surface else { return nil }
    let columns = Int(ghostty_surface_size(surface).columns)
    guard columns > 0,
      let word = readText(from: surface, { ghostty_surface_quicklook_word(surface, &$0) })
    else { return nil }
    return (word.text, word.viewportOffset / columns, word.viewportOffset % columns)
  }

  /// One row of the viewport, `nil` once freed.
  func viewportRow(_ row: Int) -> String? {
    guard let surface else { return nil }
    let lastColumn = UInt32(max(0, Int(ghostty_surface_size(surface).columns) - 1))
    let selection = ghostty_selection_s(
      top_left: ghostty_point_s(
        tag: GHOSTTY_POINT_VIEWPORT,
        coord: GHOSTTY_POINT_COORD_EXACT,
        x: 0,
        y: UInt32(row),
      ),
      bottom_right: ghostty_point_s(
        tag: GHOSTTY_POINT_VIEWPORT,
        coord: GHOSTTY_POINT_COORD_EXACT,
        x: lastColumn,
        y: UInt32(row),
      ),
      rectangle: false,
    )
    return readText(from: surface) { ghostty_surface_read_text(surface, selection, &$0) }?.text
  }

  /// `nil` where libghostty read nothing. The offset counts cells across the
  /// viewport row by row, and is zero for text not on screen.
  private func readText(
    from surface: ghostty_surface_t,
    _ fill: (inout ghostty_text_s) -> Bool,
  ) -> (text: String, viewportOffset: Int)? {
    var text = ghostty_text_s()
    guard fill(&text) else { return nil }
    defer { ghostty_surface_free_text(surface, &text) }
    guard let bytes = text.text else { return nil }
    let decoded = String(
      decoding: UnsafeRawBufferPointer(start: bytes, count: Int(text.text_len)),
      as: UTF8.self,
    )
    return (decoded, Int(text.offset_start))
  }
}
