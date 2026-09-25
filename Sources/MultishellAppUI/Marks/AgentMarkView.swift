import MultishellCore
import SwiftUI

/// The agent at a prompt, as its own mark where the app draws one and two
/// letters where it does not. A shell keeps the caller's terminal glyph.
struct AgentMarkView: View {
  static let terminalSymbol = "apple.terminal"
  /// A split tab's glyph, which the split button and a pane's badge share.
  static let splitSymbol = "rectangle.split.2x1"

  /// `nil` is a shell, or a pane nothing has reported an agent for.
  let agentID: String?
  /// Drawn in place of a mark: the tab's kind, else the terminal.
  var shellSymbol = AgentMarkView.terminalSymbol
  /// A mark with no colour of its own, the letters and the shell glyph all
  /// take the row's own text colour.
  let plainTint: Color
  let size: Double

  var body: some View {
    Group {
      if let agentID {
        mark(AgentCatalogue.mark(agentID), tint: AgentCatalogue.markTintRGB(agentID)?.color)
      } else {
        Image(systemName: shellSymbol)
          .font(.system(size: size))
          .foregroundStyle(plainTint)
      }
    }
    .frame(width: size, height: size)
  }

  @ViewBuilder
  private func mark(_ mark: AgentMark, tint: Color?) -> some View {
    if case .monogram(let letters) = mark {
      let ink = tint ?? plainTint
      Text(letters)
        .font(.system(size: size * 0.55, weight: .semibold, design: .monospaced))
        .foregroundStyle(ink)
        .frame(width: size, height: size)
        .background(ink.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.28))
    } else {
      AgentMarkShape(mark: mark)
        .fill(tint ?? plainTint)
    }
  }
}
