import MultishellCore

extension AccessibilityText {
  /// "2 comments to send", said of a file tab's title and of its panel row.
  public static func pendingReviewComments(_ count: Int) -> String {
    t("count.comments-to-send", count)
  }
}
