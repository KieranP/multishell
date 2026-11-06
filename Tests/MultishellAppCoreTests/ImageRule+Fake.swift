@testable import MultishellAppCore

extension ImageRule {
  /// `FakePlatform`'s: a `.png` name, measured as `FakeImage` writes one.
  static let fake = ImageRule(
    opensAsImage: { $0.hasSuffix(".png") },
    pixelSize: FakeImage.pixelSize,
  )
}
