import MultishellCore

/// The find bar's count, as Chrome writes it: "1/34". Matches are numbered
/// down the scrollback, the way Next walks.
public struct FindMatchCount: Equatable, Sendable {
  /// `nil` before a step selects a match.
  let position: Int?
  let total: Int

  public var text: String {
    if let position { return t("find.count", position, total) }
    return total == 0 ? t("find.count", 0, 0) : t("find.count-unselected", total)
  }

  public var spokenText: String {
    position.map { t("spoken.find-match", $0, total) } ?? t("count.matches", total)
  }
}
