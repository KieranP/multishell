import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelProjectDragTests {
  @Test func aProjectDroppedAboveOrBelowAnotherLandsOnThatSideOfIt() {
    let harness = Harness()
    let paths = [Scratch.path("drag-b"), Scratch.path("drag-c")]
    defer { paths.forEach(Scratch.remove) }
    let a = harness.project.id
    let b = harness.store.addProject(at: paths[0]).id
    let c = harness.store.addProject(at: paths[1]).id

    harness.model.moveProject(c, .above, of: a)
    #expect(harness.model.workspace.projects.map(\.id) == [c, a, b])

    harness.model.moveProject(c, .below, of: b)
    #expect(harness.model.workspace.projects.map(\.id) == [a, b, c])

    harness.model.moveProject(a, .below, of: b)
    #expect(harness.model.workspace.projects.map(\.id) == [b, a, c])

    harness.model.moveProject(c, .above, of: a)
    #expect(harness.model.workspace.projects.map(\.id) == [b, c, a])
  }

  @Test func aProjectDroppedOnItselfOrAnUnknownOneStaysPut() {
    let harness = Harness()
    let path = Scratch.path("drag-b")
    defer { Scratch.remove(path) }
    let a = harness.project.id
    let b = harness.store.addProject(at: path).id

    harness.model.moveProject(a, .below, of: a)
    harness.model.moveProject(a, .below, of: "/elsewhere")
    harness.model.moveProject("/elsewhere", .above, of: a)

    #expect(harness.model.workspace.projects.map(\.id) == [a, b])
  }

  @Test func aDragWhoseRowLeftStaysInTheAirWhileTheButtonIsDown() async {
    let harness = Harness()
    harness.model.beginProjectDrag(harness.project.id)

    harness.model.projectDragSourceLeft(harness.project.id, isPressed: { true })
    await harness.settled()

    #expect(harness.model.draggedProjectID == harness.project.id)
  }

  @Test func aDragWhoseRowLeftEndsOnceTheButtonIsUp() async {
    let harness = Harness()
    let released = AtomicFlag()
    harness.model.beginProjectDrag(harness.project.id)
    harness.model.projectDragSourceLeft(harness.project.id, isPressed: { !released.raised })

    released.raise()
    await harness.model.projectDragReleaseWatch?.value

    #expect(harness.model.draggedProjectID == nil)
  }

  @Test func aNewDragOfTheSameProjectIsNotEndedByTheLastOnesRelease() async {
    let harness = Harness()
    let released = AtomicFlag()
    harness.model.beginProjectDrag(harness.project.id)
    harness.model.projectDragSourceLeft(harness.project.id, isPressed: { !released.raised })
    let watch = harness.model.projectDragReleaseWatch

    harness.model.beginProjectDrag(harness.project.id)
    released.raise()
    await watch?.value

    #expect(harness.model.draggedProjectID == harness.project.id)
  }

  @Test func anotherProjectsRowLeavingWatchesNothing() {
    let harness = Harness()
    harness.model.beginProjectDrag(harness.project.id)

    harness.model.projectDragSourceLeft("/elsewhere", isPressed: { true })

    #expect(harness.model.projectDragReleaseWatch == nil)
  }

  @Test func anEndedDragStopsWatchingItsRow() {
    let harness = Harness()
    harness.model.beginProjectDrag(harness.project.id)
    harness.model.projectDragSourceLeft(harness.project.id, isPressed: { true })
    let watch = harness.model.projectDragReleaseWatch

    harness.model.endProjectDrag()

    #expect(harness.model.draggedProjectID == nil)
    #expect(watch?.isCancelled == true)
  }
}
