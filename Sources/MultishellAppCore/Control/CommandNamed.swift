/// An enum the command line names each case of in a word of its own.
protocol CommandNamed: CaseIterable {
  var commandName: String { get }
}

extension CommandNamed {
  init?(commandName: String) {
    guard let named = Self.allCases.first(where: { $0.commandName == commandName }) else {
      return nil
    }
    self = named
  }
}
