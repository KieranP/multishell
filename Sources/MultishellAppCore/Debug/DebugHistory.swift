/// The samples of the longest range the panel shows, oldest first.
struct DebugHistory: Sendable, Equatable {
  static let capacity = DebugRange.fifteenMinutes.sampleCount

  private(set) var samples: [DebugSample] = []

  var latest: DebugSample? { samples.last }

  var nextSequence: Int { (samples.last?.sequence ?? -1) + 1 }

  mutating func append(_ sample: DebugSample) {
    samples.append(sample)
    if samples.count > Self.capacity { samples.removeFirst(samples.count - Self.capacity) }
  }

  func samples(in range: DebugRange) -> ArraySlice<DebugSample> {
    samples.suffix(range.sampleCount)
  }
}
