/// libghostty's handle for one clipboard read. Opaque to Swift and only passed
/// back, so it is safe to send.
struct GhosttyClipboardRequest: @unchecked Sendable {
  let handle: UnsafeMutableRawPointer?
  /// Text is among the types the read takes, the one a pane serves.
  let wantsText: Bool
  /// A kitty paste event (mode 5522) asks what is on offer, naming no type.
  let wantsList: Bool

  init(handle: UnsafeMutableRawPointer?, wantsText: Bool = false, wantsList: Bool = false) {
    self.handle = handle
    self.wantsText = wantsText
    self.wantsList = wantsList
  }
}
