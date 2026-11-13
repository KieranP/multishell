import SwiftUI

/// A multi-line monospaced field on a rounded fill: a setting's script or file
/// list, and the merge form's commit message.
struct MonospacedTextEditor<Fill: ShapeStyle>: View {
  private static var inset: Double { 4 }
  private static var cornerRadius: Double { 5 }
  /// The text container's own line padding, which a placeholder has to match.
  private static var linePadding: Double { 5 }

  @Binding var text: String
  /// Drawn while the text is empty; `nil` draws none.
  let placeholder: String?
  let fontSize: Double
  let fill: Fill
  /// `nil` draws none.
  let border: Color?
  let minHeight: Double
  let maxHeight: Double
  var commit: (() -> Void)?
  var cancel: (() -> Void)?
  var takesKeyboardOnAppear = false
  var onTookKeyboard: (() -> Void)?
  var colors: PlainTextColors?

  var body: some View {
    PlainTextView(
      text: $text,
      fontSize: fontSize,
      commit: commit,
      cancel: cancel,
      takesKeyboardOnAppear: takesKeyboardOnAppear,
      onTookKeyboard: onTookKeyboard,
      colors: colors,
    )
    .frame(minHeight: minHeight, maxHeight: maxHeight)
    .padding(Self.inset)
    .overlay(alignment: .topLeading) {
      if text.isEmpty, let placeholder {
        Text(placeholder)
          .font(.system(size: fontSize, design: .monospaced))
          .foregroundStyle(colors.map { AnyShapeStyle($0.placeholder) } ?? AnyShapeStyle(.tertiary))
          .padding(.horizontal, Self.inset + Self.linePadding)
          .padding(.vertical, Self.inset)
          .allowsHitTesting(false)
      }
    }
    .background(fill, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
    .overlay {
      if let border {
        RoundedRectangle(cornerRadius: Self.cornerRadius)
          .strokeBorder(border, lineWidth: UIMetrics.hairlineThickness)
      }
    }
  }
}
