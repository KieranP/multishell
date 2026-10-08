/// Thrown rather than returning a short list, so a scan that has lost the
/// source tree fails the suite instead of passing it.
struct TranslationScanFoundNothing: Error, CustomStringConvertible {
  let count: Int

  var description: String {
    "the source scan found \(count) call sites; is the path still right?"
  }
}
