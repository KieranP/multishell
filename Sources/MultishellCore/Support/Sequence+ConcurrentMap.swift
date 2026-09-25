extension Sequence where Element: Sendable {
  /// `transform` over every element with at most `width` running at once,
  /// the results in the order they finished.
  @discardableResult
  public func concurrentMap<Result: Sendable>(
    width: Int, isolation: isolated (any Actor)? = #isolation,
    _ transform: @escaping @Sendable (Element) async -> Result
  ) async -> [Result] {
    await withTaskGroup(of: Result.self, isolation: isolation) { group in
      var pending = makeIterator()
      func startNext() {
        guard let element = pending.next() else { return }
        group.addTask { await transform(element) }
      }
      for _ in 0..<width { startNext() }

      var results: [Result] = []
      for await result in group {
        results.append(result)
        startNext()
      }
      return results
    }
  }
}
