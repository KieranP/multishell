import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelProjectDragTests {
  @Test func aProjectDroppedAboveOrBelowAnotherLandsOnThatSideOfIt() {
    let h = Harness()
    let paths = [Scratch.path("drag-b"), Scratch.path("drag-c")]
    defer { paths.forEach(Scratch.remove) }
    let a = h.project.id
    let b = h.store.addProject(at: paths[0]).id
    let c = h.store.addProject(at: paths[1]).id

    h.model.moveProject(c, .above, a)
    #expect(h.model.workspace.projects.map(\.id) == [c, a, b])

    h.model.moveProject(c, .below, b)
    #expect(h.model.workspace.projects.map(\.id) == [a, b, c])

    h.model.moveProject(a, .below, b)
    #expect(h.model.workspace.projects.map(\.id) == [b, a, c])

    h.model.moveProject(c, .above, a)
    #expect(h.model.workspace.projects.map(\.id) == [b, c, a])
  }

  @Test func aProjectDroppedOnItselfOrAnUnknownOneStaysPut() {
    let h = Harness()
    let path = Scratch.path("drag-b")
    defer { Scratch.remove(path) }
    let a = h.project.id
    let b = h.store.addProject(at: path).id

    h.model.moveProject(a, .below, a)
    h.model.moveProject(a, .below, "/elsewhere")
    h.model.moveProject("/elsewhere", .above, a)

    #expect(h.model.workspace.projects.map(\.id) == [a, b])
  }

  @Test func aDragWhoseRowLeftStaysInTheAirWhileTheButtonIsDown() async {
    let h = Harness()
    h.model.beginProjectDrag(h.project.id)

    h.model.projectDragSourceLeft(h.project.id, isPressed: { true })
    await h.settled()

    #expect(h.model.draggedProjectID == h.project.id)
  }

  @Test func aDragWhoseRowLeftEndsOnceTheButtonIsUp() async {
    let h = Harness()
    let released = Flag()
    h.model.beginProjectDrag(h.project.id)
    h.model.projectDragSourceLeft(h.project.id, isPressed: { !released.raised })

    released.raise()
    await h.model.projectDragReleaseWatch?.value

    #expect(h.model.draggedProjectID == nil)
  }

  @Test func aNewDragOfTheSameProjectIsNotEndedByTheLastOnesRelease() async {
    let h = Harness()
    let released = Flag()
    h.model.beginProjectDrag(h.project.id)
    h.model.projectDragSourceLeft(h.project.id, isPressed: { !released.raised })
    let watch = h.model.projectDragReleaseWatch

    h.model.beginProjectDrag(h.project.id)
    released.raise()
    await watch?.value

    #expect(h.model.draggedProjectID == h.project.id)
  }

  @Test func anotherProjectsRowLeavingWatchesNothing() {
    let h = Harness()
    h.model.beginProjectDrag(h.project.id)

    h.model.projectDragSourceLeft("/elsewhere", isPressed: { true })

    #expect(h.model.projectDragReleaseWatch == nil)
  }

  @Test func anEndedDragStopsWatchingItsRow() {
    let h = Harness()
    h.model.beginProjectDrag(h.project.id)
    h.model.projectDragSourceLeft(h.project.id, isPressed: { true })
    let watch = h.model.projectDragReleaseWatch

    h.model.endProjectDrag()

    #expect(h.model.draggedProjectID == nil)
    #expect(watch?.isCancelled == true)
  }
}
