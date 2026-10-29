extension OpenCodePlugin {
  static let lookupBoundMilliseconds = 1000

  /// A wait capped at a second: a hook's, so nothing slow holds OpenCode, and an
  /// event's for a hook's lookup, so a lookup that never answers holds it no longer.
  static let within = """
    const within = (promise) => new Promise((resolve) => {
      const timer = setTimeout(() => resolve(null), \(lookupBoundMilliseconds))
      if (timer.unref) timer.unref()
      const settle = (value) => { clearTimeout(timer); resolve(value) }
      promise.then(settle, () => settle(null))
    })

    """
}
