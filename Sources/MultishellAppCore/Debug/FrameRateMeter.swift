import MultishellProcess

/// Counts display frames between two readings, and the longest gap between
/// two frames, which is a stall where the count alone averages it away.
struct FrameRateMeter {
  private var framesSinceReading = 0
  private var longestFrameSinceReading = Duration.zero
  private var lastFrameAt: ContinuousClock.Instant?
  private var lastReadingAt: ContinuousClock.Instant?

  mutating func noteFrame(at instant: ContinuousClock.Instant) {
    if let lastFrameAt {
      longestFrameSinceReading = max(longestFrameSinceReading, lastFrameAt.duration(to: instant))
    }
    lastFrameAt = instant
    framesSinceReading += 1
  }

  /// A reading no later than this after the one before had the main thread
  /// free, the sampler running on it too; a stall holds both up.
  static let onTimeLimit = Duration.milliseconds(1_500)

  /// `nil` for the first reading, which has nothing to count from, and for
  /// one with no frame: a display asleep, not a main thread stalled.
  mutating func takeReading(at instant: ContinuousClock.Instant) -> FrameRateReading? {
    defer {
      framesSinceReading = 0
      longestFrameSinceReading = .zero
      lastReadingAt = instant
    }
    guard let lastReadingAt else { return nil }
    guard framesSinceReading > 0 else {
      // On time and frameless: the display stopped, so the gap to its next
      // frame is no stall.
      if lastReadingAt.duration(to: instant) <= Self.onTimeLimit { lastFrameAt = nil }
      return nil
    }
    let elapsed = lastReadingAt.duration(to: instant).inSeconds
    guard elapsed > 0 else { return nil }
    return FrameRateReading(
      framesPerSecond: Double(framesSinceReading) / elapsed, longestFrame: longestFrameSinceReading)
  }
}
