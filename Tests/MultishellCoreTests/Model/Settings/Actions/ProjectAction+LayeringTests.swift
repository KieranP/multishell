import Testing

@testable import MultishellCore

@Suite
struct ProjectActionLayeringTests {
  @Test func layeredTheUsersOwnComeFirstInTheirOrderThenTheFilesOthersInItsOrder() {
    let ownServe = ProjectAction(name: "Start Server", command: "bin/dev")
    let tail = ProjectAction(name: "Tail Logs", command: "tail -f log/development.log")

    let layered = ProjectAction.layered(own: [tail, ownServe], over: [.serve, .migrate, .seed])

    #expect(layered == [tail, ownServe, .migrate, .seed])
    #expect(ProjectAction.layered(own: [], over: [.seed, .serve]) == [.seed, .serve])
  }
}
