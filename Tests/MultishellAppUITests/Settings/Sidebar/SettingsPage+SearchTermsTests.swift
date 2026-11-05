import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct SettingsPageSearchTermsTests {
  @Test func theInstallRowIsFoundByTheWordsOnItsLabelAndButton() {
    for query in ["CLI", "multishell"] {
      let found = SettingsSearch.pages(in: .allProjects, matching: query) { page in
        page.searchTerms(in: .allProjects)
      }
      #expect(found.contains(.agents), "\(query)")
    }
  }
}
