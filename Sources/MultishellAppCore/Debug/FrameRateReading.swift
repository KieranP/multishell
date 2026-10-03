/// How many display frames the main thread answered in a second, and the
/// longest it kept one waiting.
struct FrameRateReading: Sendable, Equatable {
  let framesPerSecond: Double
  let longestFrame: Duration
}
