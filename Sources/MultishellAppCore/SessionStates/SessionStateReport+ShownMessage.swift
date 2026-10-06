import MultishellCore

extension SessionStateReport {
  /// The message as the banner and the card show it. A question is worded
  /// here, the helper that spotted it having no catalogue to read.
  var shownMessage: String? {
    asksQuestion == true ? t("notification.agent-question") : message
  }
}
