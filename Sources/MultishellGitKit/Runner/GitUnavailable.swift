public struct GitUnavailable: Error, CustomStringConvertible {
  public var description: String { "git was not found on PATH" }

  public init() {}
}
