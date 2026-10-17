/// A theme file that would not load. The reason is the decoder's, whose text
/// varies between reads of one file, so a file is known by its name.
public struct ThemeFileProblem: Sendable {
  public let fileName: String
  let reason: String

  public var message: String { "\(fileName): \(reason)" }
}
