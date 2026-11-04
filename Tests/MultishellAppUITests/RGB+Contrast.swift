import Foundation

@testable import MultishellCore

extension RGB {
  private var luminance: Double {
    func channel(_ value: UInt8) -> Double {
      let linear = Double(value) / 255
      return linear <= 0.03928 ? linear / 12.92 : pow((linear + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
  }

  /// WCAG's ratio of the lighter colour's luminance to the darker's, alpha ignored.
  func contrast(with other: RGB) -> Double {
    let luminances = [luminance, other.luminance]
    return (luminances.max()! + 0.05) / (luminances.min()! + 0.05)
  }

  /// This colour laid over an opaque one at its own alpha, as a wash draws.
  func composited(over background: RGB) -> RGB {
    func mix(_ top: UInt8, _ bottom: UInt8) -> UInt8 {
      UInt8((Double(top) * opacity + Double(bottom) * (1 - opacity)).rounded())
    }
    return RGB(
      red: mix(red, background.red),
      green: mix(green, background.green),
      blue: mix(blue, background.blue),
    )
  }
}
