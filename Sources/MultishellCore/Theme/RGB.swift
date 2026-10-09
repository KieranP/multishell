import Foundation

/// A colour as the core carries one: three channels and no alpha, which is
/// what a terminal cell has. A GUI turns it into its own colour type.
public struct RGB: Hashable, Sendable {
  public static let white = Self(red: 255, green: 255, blue: 255)
  public static let black = Self(red: 0, green: 0, blue: 0)

  public let red: UInt8
  public let green: UInt8
  public let blue: UInt8

  /// `#rrggbb`, the form a theme file and a Ghostty config both take.
  public var hex: String {
    String(format: "#%02x%02x%02x", red, green, blue)
  }

  /// Mixes towards `other`, where 0 is self and 1 is `other`.
  public func blended(with other: Self, amount: Double) -> Self {
    let ratio = amount.clamped(to: 0...1)
    func mix(_ a: UInt8, _ b: UInt8) -> UInt8 {
      UInt8((Double(a) * (1 - ratio) + Double(b) * ratio).rounded())
    }
    return Self(
      red: mix(red, other.red),
      green: mix(green, other.green),
      blue: mix(blue, other.blue),
    )
  }
}
