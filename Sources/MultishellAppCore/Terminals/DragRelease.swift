/// Waits out a drag no drag session will end: until the button is up, then
/// `grace` more, so a drop that did land has read the drag first.
enum DragRelease {
  @MainActor
  static func wait(
    isPressed: @MainActor () -> Bool, every interval: Duration = .milliseconds(100),
    grace: Duration = .milliseconds(250)
  ) async {
    while !Task.isCancelled, isPressed() {
      try? await Task.sleep(for: interval)
    }
    try? await Task.sleep(for: grace)
  }
}
