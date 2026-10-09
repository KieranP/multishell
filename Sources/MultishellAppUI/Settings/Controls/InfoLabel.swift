import SwiftUI

struct InfoLabel: View {
  private static let inlineSpacing: CGFloat = 4
  private static let sectionHeaderSpacing: CGFloat = 6

  let text: String
  let info: String
  private let spacing: CGFloat

  var body: some View {
    HStack(spacing: spacing) {
      Text(text)
      InfoButton(info)
    }
  }

  init(_ text: String, info: String) {
    self.init(text, info: info, spacing: Self.inlineSpacing)
  }

  init(sectionHeader text: String, info: String) {
    self.init(text, info: info, spacing: Self.sectionHeaderSpacing)
  }

  private init(_ text: String, info: String, spacing: CGFloat) {
    self.text = text
    self.info = info
    self.spacing = spacing
  }
}
