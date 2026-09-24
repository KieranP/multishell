import Foundation

/// Waits out a drag the platform gives no end for: until the button is up,
/// then `grace` more, so a drop that did land has read the drag first.
public enum DragRelease {
  public static let poll: Duration = .milliseconds(100)
  public static let dropGrace: Duration = .milliseconds(250)

  public static func wait(
    isPressed: @MainActor () -> Bool, every interval: Duration = poll,
    grace: Duration = dropGrace
  ) async {
    while await isPressed() {
      try? await Task.sleep(for: interval)
    }
    try? await Task.sleep(for: grace)
  }
}
