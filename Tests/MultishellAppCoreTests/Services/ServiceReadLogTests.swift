import Testing

@testable import MultishellAppCore

@Suite
struct ServiceReadLogTests {
  private let start = ContinuousClock.now

  @Test func aProjectNeverAskedIsDueAndOneAskedIsDueAgainAfterTheInterval() {
    var log = ServiceReadLog<String>()
    #expect(log.isDue("/p", at: start))
    let began = log.begin("/p", at: start)
    log.finish("/p")

    #expect(began)
    #expect(!log.isDue("/p", at: start + .seconds(119)))
    #expect(log.isDue("/p", at: start + ServiceReadInterval.poll))
    #expect(log.isDue("/p", at: start + .seconds(30), interval: ServiceReadInterval.activation))
  }

  @Test func aProjectBeingAskedIsNeitherDueNorBegunAgain() {
    var log = ServiceReadLog<String>()
    _ = log.begin("/p", at: start)
    let beganAgain = log.begin("/p", at: start + .seconds(600))

    #expect(!beganAgain)
    #expect(!log.isDue("/p", at: start + .seconds(600)))
  }

  @Test func aForgottenProjectIsAsIfNeverAsked() {
    var log = ServiceReadLog<String>()
    _ = log.begin("/p", at: start)
    log.forget("/p")

    #expect(!log.hasAsked("/p"))
    #expect(log.isDue("/p", at: start))
  }
}
