public struct GitUnavailable: Error, CustomStringConvertible {
  public init() {}
  public var description: String { "git was not found on PATH" }
}
