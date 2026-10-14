import SwiftUI

struct InfoLabel: View {
  private static let inlineSpacing: CGFloat = 4
  private static let sectionHeaderSpacing: CGFloat = 6

  let label: String
  let info: String
  private let spacing: CGFloat

  var body: some View {
    HStack(spacing: spacing) {
      Text(label)
      InfoButton(info)
    }
  }

  init(_ label: String, info: String) {
    self.init(label, info: info, spacing: Self.inlineSpacing)
  }

  init(sectionHeader label: String, info: String) {
    self.init(label, info: info, spacing: Self.sectionHeaderSpacing)
  }

  private init(_ label: String, info: String, spacing: CGFloat) {
    self.label = label
    self.info = info
    self.spacing = spacing
  }
}
