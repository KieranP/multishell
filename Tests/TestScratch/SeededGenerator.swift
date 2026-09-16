/// Deterministic, so a failing sequence can be replayed from its seed.
public struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64

  public init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

  public mutating func next() -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}
