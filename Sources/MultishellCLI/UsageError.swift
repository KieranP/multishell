struct UsageError: Error {
  let message: String
  init(_ message: String) { self.message = message }
}
