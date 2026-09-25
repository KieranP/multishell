import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct EditorCatalogueDisplayNameTests {
  @Test func catalogueIdsBecomeNames() {
    #expect(EditorCatalogue.displayName("zed") == "Zed")
    #expect(EditorCatalogue.displayName("custom") == "Custom command")
  }
}
