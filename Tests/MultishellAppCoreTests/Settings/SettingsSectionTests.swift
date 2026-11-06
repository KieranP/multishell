import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct SettingsSectionTests {
  private static let scopes = [SettingsScope.allProjects, .project("/repo")]

  @Test func everySectionBelongsToThePageThatListsIt() {
    for scope in Self.scopes {
      for page in SettingsPage.pages(in: scope) {
        for section in page.sections(in: scope) {
          #expect(section.page == page, "\(section) listed under \(page)")
        }
      }
    }
  }

  @Test func onlyThePartsOfASplitPageAreParts() {
    let parts: [SettingsSection] = [
      .agentSettings, .agentHooks, .hooksCreate, .hooksDelete, .hooksEnvironment,
    ]
    #expect(parts.allSatisfy { $0.isPart })
    for scope in Self.scopes {
      for page in SettingsPage.pages(in: scope) {
        let sections = page.sections(in: scope)
        #expect(sections.allSatisfy { $0.isPart == (sections.count > 1) }, "\(page) in \(scope)")
      }
    }
  }
}
