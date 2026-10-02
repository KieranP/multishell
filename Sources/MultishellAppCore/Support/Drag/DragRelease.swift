/// Waits out a drag no drag session will end: until the button is up, then
/// `grace` more, so a drop that did land has read the drag first.
enum DragRelease {
  private static let pollInterval: Duration = .milliseconds(100)
  private static let grace: Duration = .milliseconds(250)

  @MainActor
  private static func wait(isPressed: @MainActor () -> Bool) async {
    while !Task.isCancelled, isPressed() {
      try? await Task.sleep(for: pollInterval)
    }
    try? await Task.sleep(for: grace)
  }

  /// Runs `end` once the wait is over, unless the returned task is cancelled
  /// first, which is how a new drag takes over from the last one's watch.
  @MainActor
  static func watch(
    isPressed: @escaping @MainActor () -> Bool, then end: @escaping @MainActor () -> Void
  ) -> Task<Void, Never> {
    Task { @MainActor in
      await wait(isPressed: isPressed)
      guard !Task.isCancelled else { return }
      end()
    }
  }
}
