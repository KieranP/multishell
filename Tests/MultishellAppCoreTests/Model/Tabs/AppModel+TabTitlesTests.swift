import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabTitlesTests {
  @Test func aPaneInheritsItsTabsCustomNameOverTheShellsTitle() {
    let harness = Harness()
    let model = harness.model
    model.select(harness.main)
    let tab = model.workspace.activeTab(in: harness.main.id)!
    let session = model.workspace.session(tab.focusedSessionID)!
    model.noteTitle("make release", of: session.id)
    #expect(model.title(ofPane: session, in: tab) == "make release")

    model.renameTab(tab.id, to: "build")
    let renamed = model.workspace.tab(tab.id)!
    #expect(model.title(ofPane: session, in: renamed) == "build")
    #expect(model.title(of: renamed) == "build", "the strip and the rows agree")
  }

  @Test func theShownTitlesDropAnAgentsStatusGlyphWhileTheRawTitlesKeepIt() {
    let harness = Harness()
    let model = harness.model
    model.select(harness.main)
    let tab = model.workspace.activeTab(in: harness.main.id)!
    let session = model.workspace.session(tab.focusedSessionID)!
    model.noteTitle("✳ Request authentication", of: session.id)

    #expect(model.shownTitle(of: tab) == "Request authentication")
    #expect(model.sidebarPanes(of: harness.main).map(\.title) == ["Request authentication"])
    #expect(model.title(of: tab) == "✳ Request authentication")
    #expect(model.title(ofPane: session, in: tab) == "✳ Request authentication")
  }

  @Test func aShellAtItsWorktreesRootIsShownAsAShell() {
    let harness = Harness()
    let model = harness.model
    model.select(harness.main)
    let tab = model.workspace.activeTab(in: harness.main.id)!
    model.noteTitle(harness.main.path.path, of: tab.focusedSessionID)

    #expect(model.shownTitle(of: tab) == t("tab.shell"))
  }
}
