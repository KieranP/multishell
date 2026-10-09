import MultishellCore

extension DebugTimeline {
  /// The range's stalls, as the panel's header sums them up.
  public var stallSummary: String {
    t(
      "debug.stalled-seconds",
      t("count.stalled-seconds", stalledSecondCount),
      DebugValueText.duration(Smoothness.stallThreshold),
    )
  }
}
