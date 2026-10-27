import Foundation
import MultishellCore

/// What a screen reader says for the quick switcher's rows, as each is drawn.
extension AccessibilityText {
  /// Also announced as the arrows reach the row.
  public static func quickSwitcherRow(_ item: QuickSwitcherItem, at now: Date) -> String {
    // Each step of a path said as a list item, not its mark read aloud by name.
    let steps = [item.title, item.location].flatMap { text in
      text.components(separatedBy: QuickSwitcherItem.pathStep)
    }
    var parts = steps.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    if let position = item.position { parts.append(panePosition(position)) }
    if let state = item.labelledState { parts.append(state.displayName) }
    if let elapsed = item.elapsed(at: now) { parts.append(t("spoken.elapsed", elapsed)) }
    if item.isChecked { parts.append(t("spoken.checked")) }
    if let shortcut = item.shortcut { parts.append(shortcut) }
    return parts.joined(separator: ", ")
  }
}
