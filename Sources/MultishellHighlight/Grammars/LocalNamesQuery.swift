import Foundation
import SwiftTreeSitter

/// The names a file declares, by its grammar's locals query: what `#is-not? local`
/// asks. File-wide rather than per scope, so a name declared anywhere is local everywhere.
struct LocalNamesQuery: Sendable {
  private static let definition = "local.definition"

  private let query: Query

  /// Only the definitions are kept: the reference pattern captures every name in the file.
  init(source: String, language: Language) throws {
    let definitions = source.replacing(#/\(identifier\) @local\.reference/#, with: "")
    query = try Query(language: language, data: Data(definitions.utf8))
  }

  /// `string`'s text for the highlights' own predicates, and `local` answered from `names`.
  static func context(
    for string: String,
    declaring names: Set<String>,
  ) -> SwiftTreeSitter.Predicate.Context {
    let text = string as NSString
    return Predicate.Context(
      textProvider: string.predicateTextProvider,
      groupMembershipProvider: { group, range, _ in
        group == "local" && names.contains(text.substring(with: range))
      },
    )
  }

  func names(in tree: MutableTree, text: String) -> Set<String> {
    let units = text as NSString
    let matches = query.execute(in: tree).resolve(with: Predicate.Context(string: text))
    var names: Set<String> = []
    for capture in matches.lazy.flatMap(\.captures) where capture.name == Self.definition {
      names.insert(units.substring(with: capture.range))
    }
    return names
  }
}
