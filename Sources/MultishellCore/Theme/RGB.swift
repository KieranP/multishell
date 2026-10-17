import Foundation

/// A colour as the core carries one: three channels and an alpha. A GUI turns
/// it into its own colour type; a terminal cell takes no alpha, see `opaque`.
public struct RGB: Hashable, Sendable {
  public static let black = Self(red: 0, green: 0, blue: 0)

  public let red: UInt8
  public let green: UInt8
  public let blue: UInt8
  /// 255 is opaque.
  public let alpha: UInt8

  /// `#rrggbb` whatever the alpha: a Ghostty config refuses a fourth channel.
  public var opaqueHex: String {
    String(format: "#%02x%02x%02x", red, green, blue)
  }

  public var opacity: Double { Double(alpha) / 255 }

  public var opaque: Self { Self(red: red, green: green, blue: blue) }

  public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
  }
}
