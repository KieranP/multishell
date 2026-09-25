import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct ProjectDragTests {
  @Test func aDragWhoseRowLeftStaysInTheAirWhileTheButtonIsDown() async {
    let h = Harness()
    h.model.beginProjectDrag(h.project.id)

    h.model.projectDragSourceLeft(h.project.id, isPressed: { true })
    await h.settled()

    #expect(h.model.draggingProject == h.project.id)
  }

  @Test func aDragWhoseRowLeftEndsOnceTheButtonIsUp() async {
    let h = Harness()
    let released = Flag()
    h.model.beginProjectDrag(h.project.id)
    h.model.projectDragSourceLeft(h.project.id, isPressed: { !released.raised })

    released.raise()
    await h.model.projectDragReleaseWatch?.value

    #expect(h.model.draggingProject == nil)
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

    #expect(h.model.draggingProject == h.project.id)
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

    #expect(h.model.draggingProject == nil)
    #expect(watch?.isCancelled == true)
  }
}
