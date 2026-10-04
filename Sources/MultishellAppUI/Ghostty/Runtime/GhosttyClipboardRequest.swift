/// libghostty's handle for one clipboard read. Opaque to Swift and only passed
/// back, so it is safe to send.
struct GhosttyClipboardRequest: @unchecked Sendable {
  let handle: UnsafeMutableRawPointer?
  /// Text is among the types the read takes, the one a pane serves.
  var wantsText = false
  /// A kitty paste event (mode 5522) asks what is on offer, naming no type.
  var wantsList = false
}
