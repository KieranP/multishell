import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct NewWorktreeRequestTests {
  @Test func theMenuWithOneProjectAndNothingSelectedPicksThatProject() {
    let h = Harness()
    h.model.requestNewWorktree()
    #expect(h.model.newWorktreeRequest?.projectID == h.project.id)
  }

  @Test func theMenuWithSeveralProjectsAndNothingSelectedOpensWithNoProject() {
    let h = Harness()
    h.store.addProject(at: URL(fileURLWithPath: "/other"))

    h.model.requestNewWorktree()

    #expect(h.model.newWorktreeRequest != nil, "used to do nothing, silently")
    #expect(h.model.newWorktreeRequest?.projectID == nil, "the picker starts blank")
  }

  @Test func theMenuOverTheBoardWithSeveralProjectsOpensWithNoProject() {
    let h = Harness()
    h.store.addProject(at: URL(fileURLWithPath: "/other"))
    h.model.select(h.feature)
    h.model.showAgentBoard()

    h.model.requestNewWorktree()

    #expect(h.model.newWorktreeRequest?.projectID == nil, "nothing on screen names a project")
  }

  @Test func theMenuFollowsTheSelectedWorktreesProject() {
    let h = Harness()
    let other = h.store.addProject(at: URL(fileURLWithPath: "/other"))
    h.model.select(h.feature)

    h.model.requestNewWorktree()

    #expect(h.model.newWorktreeRequest?.projectID == h.project.id)
    #expect(h.model.newWorktreeRequest?.projectID != other.id)
  }

  @Test func theSidebarNamesItsProjectWhateverIsSelected() {
    let h = Harness()
    let other = h.store.addProject(at: URL(fileURLWithPath: "/other"))
    h.model.select(h.main)

    h.model.requestNewWorktree(in: other)

    #expect(h.model.newWorktreeRequest?.projectID == other.id)
  }

  @Test func eachRequestIsANewPresentation() {
    let h = Harness()
    h.model.requestNewWorktree()
    let first = h.model.newWorktreeRequest?.id
    h.model.newWorktreeRequest = nil
    h.model.requestNewWorktree()
    #expect(h.model.newWorktreeRequest?.id != first, "the sheet must reopen after a cancel")
  }
}
