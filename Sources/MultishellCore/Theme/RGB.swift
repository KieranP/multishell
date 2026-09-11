import Foundation

/// A colour as the core carries one: three channels and no alpha, which is
/// what a terminal cell has. A GUI turns it into its own colour type.
public struct RGB: Hashable, Sendable {
  public let red: UInt8
  public let green: UInt8
  public let blue: UInt8

  public init(red: UInt8, green: UInt8, blue: UInt8) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  /// Mixes towards `other`, where 0 is self and 1 is `other`.
  public func blended(with other: RGB, amount: Double) -> RGB {
    let ratio = min(max(amount, 0), 1)
    func mix(_ a: UInt8, _ b: UInt8) -> UInt8 {
      UInt8((Double(a) * (1 - ratio) + Double(b) * ratio).rounded())
    }
    return RGB(
      red: mix(red, other.red), green: mix(green, other.green), blue: mix(blue, other.blue))
  }

  public static let white = RGB(red: 255, green: 255, blue: 255)
  public static let black = RGB(red: 0, green: 0, blue: 0)
}
