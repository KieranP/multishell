import Foundation
import MultishellCore
import MultishellServices
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite @MainActor
struct AppModelControlFilesTests {
  private static func paths(in reply: ControlReply?) -> [String] {
    (reply?.outputFields["rows"] as? [[String: Any]] ?? []).compactMap { $0["path"] as? String }
  }

  private func panelListingFiles() -> Harness {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setFilesPanelMode(.files)
    harness.model.setShowsFilesPanel(true)
    harness.model.trackedFiles[harness.main.id] = TrackedFiles(
      paths: ["README.md", "src/app.swift", "src/build.swift"],
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )
    return harness
  }

  @Test func theListIsTheRowsThePanelDrawsForTheWorktreeInView() async throws {
    let harness = panelListingFiles()

    let reply = try #require(await harness.messageSource.ask(.listFiles))

    #expect(reply.outputFields["worktree"] as? String == ControlID.worktree(harness.main.id))
    #expect(reply.outputFields["page"] as? String == "files")
    #expect(Self.paths(in: reply) == ["src", "README.md"])
  }

  @Test func expandingAFolderListsItsFilesAndCollapsingHidesThem() async {
    let harness = panelListingFiles()

    let expanded = await harness.messageSource.ask(
      .setFilesFolderExpanded(path: "src", expanded: true)
    )
    let collapsed = await harness.messageSource.ask(
      .setFilesFolderExpanded(path: "src", expanded: false)
    )

    #expect(Self.paths(in: expanded) == ["src", "src/app.swift", "src/build.swift", "README.md"])
    #expect(Self.paths(in: collapsed) == ["src", "README.md"])
  }

  @Test func aFolderTheListDoesNotShowIsRefused() async {
    let harness = panelListingFiles()

    let reply = await harness.messageSource.ask(
      .setFilesFolderExpanded(path: "lib", expanded: true)
    )

    #expect(reply == .refused(.noFilesFolder(path: "lib")))
  }

  @Test func theFilterListsTheMatchingFilesFlatAndEmptyClearsIt() async {
    let harness = panelListingFiles()

    let filtered = await harness.messageSource.ask(.filterFiles(text: "build"))
    let cleared = await harness.messageSource.ask(.filterFiles(text: ""))

    #expect(Self.paths(in: filtered) == ["src/build.swift"])
    #expect(filtered?.outputFields["filterText"] as? String == "build")
    #expect(Self.paths(in: cleared) == ["src", "README.md"])
  }

  @Test func aShutPanelOrAServicesPageIsRefused() async throws {
    let harness = panelListingFiles()
    harness.model.remoteState.connections = ServiceConnections(
      standIn: try ServiceStandIn(json: "{}")
    )
    harness.model.setFilesPanelMode(.pullRequest)
    let onAPage = await harness.messageSource.ask(.listFiles)
    harness.model.setFilesPanelMode(.files)
    harness.model.setShowsFilesPanel(false)

    let shut = await harness.messageSource.ask(.listFiles)

    #expect(onAPage == .refused(.filesPanelListsNoFiles))
    #expect(shut == .refused(.filesPanelListsNoFiles))
  }

  @Test func aListingStillBeingBuiltSaysSo() async {
    let harness = panelListingFiles()
    harness.model.trackedFiles[harness.main.id] = TrackedFiles(
      paths: (0..<30_000).map { "src/file\($0).txt" },
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )

    let reply = await harness.messageSource.ask(.listFiles)

    #expect(reply?.outputFields["isReading"] as? Bool == true)
  }

  @Test func aFolderStillBeingReadSaysTheListIsReading() async {
    let harness = panelListingFiles()
    harness.model.pendingStatusRefreshes.removeValue(forKey: harness.main.id)?.cancel()
    let before = await harness.messageSource.ask(.listFiles)
    let folder = PanelFolderRead(kind: .ignoredFolder, path: "build", worktreeID: harness.main.id)
    harness.model.panelFolderReads.start(folder) { Task {} }

    let reply = await harness.messageSource.ask(.listFiles)

    #expect(before?.outputFields["isReading"] as? Bool == false)
    #expect(reply?.outputFields["isReading"] as? Bool == true)
  }

  @Test func aPanelOpenOverNoWorktreeSaysNoneIsInView() async {
    let harness = Harness()
    harness.model.setShowsFilesPanel(true)

    let reply = await harness.messageSource.ask(.listFiles)

    #expect(reply == .refused(.nothingInView))
  }

  @Test func aBranchListStillUnreadSaysTheListIsReading() async {
    let harness = panelListingFiles()
    harness.model.pendingStatusRefreshes.removeValue(forKey: harness.main.id)?.cancel()
    harness.model.setChangeScope(.branch)
    harness.model.setFilesPanelMode(.changes)

    let reply = await harness.messageSource.ask(.listFiles)

    #expect(reply?.outputFields["isReading"] as? Bool == true)
  }
}
