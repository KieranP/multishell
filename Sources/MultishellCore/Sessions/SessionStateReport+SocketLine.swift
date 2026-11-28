import MultishellProcess

extension SessionStateReport {
  /// One socket line, less the workers out where they would pass what the server
  /// reads: no list prunes nothing, where a dropped line lost the whole report.
  public func encodedLineFittingTheSocket() throws -> String {
    let line = try encodedLine()
    guard line.utf8.count > UnixSocketServer.maximumLineLength else { return line }
    var listless = self
    listless.workersOut = nil
    return try listless.encodedLine()
  }
}
