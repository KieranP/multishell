extension Duration {
  /// One clock step for a card's corner, a pane row's rail and a switcher row's
  /// wait. A time under a minute lags by up to this; past a minute it barely shows.
  static let elapsedTick: Duration = .seconds(10)
}
