import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct WorktreeRowBadgeFitTests {
  private static let fits: [WorktreeRowBadgeFit] = [
    .all, .withoutCount, .withoutServices, .alertsOnly,
  ]

  private static var servicesWithARun: WorktreeServices {
    var services = WorktreeServices()
    services.ciRun = .sample()
    return services
  }

  @Test func aCrowdedRowGivesUpTheCountThenTheServicesThenTheGitState() {
    #expect(Self.fits.map { $0.showsCount(of: 2) } == [true, false, false, false])
    #expect(
      Self.fits.map { $0.showsServices(Self.servicesWithARun) } == [true, true, false, false]
    )
    #expect(Self.fits.map(\.showsGitState) == [true, true, true, false])
  }

  @Test func aRowWithNothingToShowDrawsNoCountOrServicesAtAnyFit() {
    #expect(Self.fits.allSatisfy { !$0.showsCount(of: 0) })
    #expect(Self.fits.allSatisfy { !$0.showsServices(WorktreeServices()) })
  }
}
