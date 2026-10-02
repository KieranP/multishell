import Foundation
import Testing

@testable import MultishellCore

@Suite
struct EditorCatalogueTests {
  @Test func noneAndEmptyMeanNoEditor() {
    #expect(EditorCatalogue.effectiveID(nil) == nil)
    #expect(EditorCatalogue.effectiveID("") == nil)
    #expect(EditorCatalogue.effectiveID(EditorCatalogue.noneID) == nil)
    #expect(EditorCatalogue.effectiveID("vscode") == "vscode")
  }

  @Test func anAppEditorHasABundleAndATerminalOneIsMarkedSo() {
    #expect(EditorCatalogue.editor("vscode")?.bundleIdentifier == "com.microsoft.VSCode")
    #expect(EditorCatalogue.editor("nvim")?.kind == .terminal)
  }

  @Test func noTwoEditorsShareAnIdAndNoneTakesAReservedOne() {
    let ids = EditorCatalogue.editors.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(!ids.contains(EditorCatalogue.noneID) && !ids.contains(EditorCatalogue.customID))
  }
}
