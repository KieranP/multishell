/// How smooth a second was, judged by its longest frame, which reads the same
/// on a 60 Hz display as on a 120 Hz one where a frame count would not.
public enum Smoothness: Sendable, Equatable {
  case smooth
  /// Two frames missed at 60 Hz: a hitch someone notices.
  case hitched
  /// A tenth of a second or more, which reads as the app hanging.
  case stalled

  static let hitchThreshold = Duration.milliseconds(50)
  public static let stallThreshold = Duration.milliseconds(100)

  static func of(longestFrame: Duration?) -> Smoothness {
    guard let longestFrame else { return .smooth }
    if longestFrame >= stallThreshold { return .stalled }
    return longestFrame >= hitchThreshold ? .hitched : .smooth
  }
}
