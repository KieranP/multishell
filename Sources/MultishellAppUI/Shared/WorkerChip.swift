import MultishellAppCore
import MultishellCore
import SwiftUI

/// The count of workers an agent has out in the Working colour, or of failed
/// ones once none is. Hovering it lists them; see Docs/design/agents.md.
struct WorkerChip: View {
  /// Long enough to cross from the chip onto the list without it closing,
  /// short enough that it goes with the pointer.
  private static let hideDelay: Duration = .milliseconds(250)

  let workers: [Worker]
  let theme: Theme
  let metrics: UIMetrics

  @State private var isHovered = false
  @State private var showsList = false
  @State private var hideTask: Task<Void, Never>?

  var body: some View {
    HStack(spacing: 3) {
      WorkerGlyph(metrics: metrics)
      Text("\(workers.chipCount)")
        .font(.system(size: metrics.badge, weight: .semibold))
        .monospacedDigit()
    }
    .foregroundStyle(theme.color(for: workers.chipState))
    .padding(.horizontal, 5)
    .padding(.vertical, 1)
    .background(
      theme.color(for: workers.chipState).opacity(isHovered ? 0.26 : 0.14),
      in: Capsule(),
    )
    .contentShape(.rect)
    .onHover { hovering in
      isHovered = hovering
      hoverChanged(hovering)
    }
    .popover(isPresented: $showsList, arrowEdge: .bottom) {
      WorkerList(workers: workers, theme: theme, metrics: metrics)
        .onHover(perform: hoverChanged)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.workers(workers))
    .onDisappear { hideTask?.cancel() }
  }

  private func hoverChanged(_ hovering: Bool) {
    hideTask?.cancel()
    guard !hovering else {
      showsList = true
      return
    }
    hideTask = Task { @MainActor in
      try? await Task.sleep(for: Self.hideDelay)
      guard !Task.isCancelled else { return }
      showsList = false
    }
  }
}
