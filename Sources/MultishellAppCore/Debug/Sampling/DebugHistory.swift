/// The samples of the longest range the panel shows, oldest first.
struct DebugHistory: Sendable, Equatable {
  private static let capacity = DebugRange.fifteenMinutes.sampleCount

  private(set) var samples: [DebugSample] = []
  /// Past the last history's, so a follow from the command line never sees a
  /// number again once the tools go off and on.
  private let firstSequence: Int

  var latest: DebugSample? { samples.last }

  var nextSequence: Int { samples.last.map { $0.sequence + 1 } ?? firstSequence }

  init(numberingFrom firstSequence: Int = 0) {
    self.firstSequence = firstSequence
  }

  mutating func append(_ sample: DebugSample) {
    samples.append(sample)
    samples.keepLast(Self.capacity)
  }

  func samples(in range: DebugRange) -> ArraySlice<DebugSample> {
    samples.suffix(range.sampleCount)
  }
}
