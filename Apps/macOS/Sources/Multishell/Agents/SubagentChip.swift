import MultishellAppCore
import MultishellCore
import SwiftUI

/// The count of workers an agent has out, in the Working colour, drawn only
/// while there is one. Hovering it lists them; see docs/design/agents.md.
struct SubagentChip: View {
  let subagents: [Subagent]
  let theme: Theme
  let metrics: UIMetrics

  @State private var isHovered = false
  @State private var showsList = false
  @State private var hide: Task<Void, Never>?

  /// Long enough to cross from the chip onto the list without it closing,
  /// short enough that it goes with the pointer.
  private static let lingers: Duration = .milliseconds(250)

  var body: some View {
    HStack(spacing: 3) {
      Image(systemName: "arrow.triangle.branch")
        .font(.system(size: metrics.badge - 1, weight: .semibold))
      Text("\(subagents.workerCount)")
        .font(.system(size: metrics.badge, weight: .semibold))
        .monospacedDigit()
    }
    .foregroundStyle(theme.color(for: .running))
    .padding(.horizontal, 5)
    .padding(.vertical, 1)
    .background(theme.color(for: .running).opacity(isHovered ? 0.26 : 0.14), in: Capsule())
    .contentShape(.rect)
    .onHover { hovering in
      isHovered = hovering
      keepList(hovering)
    }
    .popover(isPresented: $showsList, arrowEdge: .bottom) {
      SubagentList(subagents: subagents, theme: theme, metrics: metrics)
        .onHover(perform: keepList)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.subagents(subagents))
    .onDisappear { hide?.cancel() }
  }

  private func keepList(_ hovering: Bool) {
    hide?.cancel()
    guard !hovering else {
      showsList = true
      return
    }
    hide = Task { @MainActor in
      try? await Task.sleep(for: Self.lingers)
      guard !Task.isCancelled else { return }
      showsList = false
    }
  }
}
