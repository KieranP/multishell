import MultishellCore

extension AccessibilityText {
  /// "2 comments to send", said of a file or All changes tab, a panel row and a file header.
  public static func pendingReviewComments(_ count: Int) -> String {
    t("count.comments-to-send", count)
  }
}
