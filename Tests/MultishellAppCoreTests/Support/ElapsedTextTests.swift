import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct ElapsedTextTests {
  @Test func aGlanceIsSecondsThenMinutesThenHours() {
    #expect(ElapsedText.short(0) == "0s")
    #expect(ElapsedText.short(41) == "41s")
    #expect(ElapsedText.short(59.9) == "59s")
    #expect(ElapsedText.short(60) == "1m")
    #expect(ElapsedText.short(750) == "12m")
    #expect(ElapsedText.short(3900) == "1h 05m")
    #expect(ElapsedText.short(-1) == nil, "a clock that moved backwards says nothing")
    #expect(ElapsedText.short(.infinity) == nil)
  }

  /// `Int(_: Double)` traps outside its range, and the board draws whatever
  /// duration a report carried.
  @Test func aDurationTooLargeToRenderSaysNothingRatherThanTrapping() {
    #expect(ElapsedText.short(1e300) == nil)
    #expect(ElapsedText.precise(1e300) == nil)
    #expect(ElapsedText.short(.nan) == nil)
    #expect(ElapsedText.short(Double(Int.max)) == nil, "the first value it cannot hold")
  }

  @Test func aCommandsRuntimeKeepsItsSeconds() {
    #expect(ElapsedText.precise(0.42) == "0.4s")
    #expect(ElapsedText.precise(9.5) == "9.5s")
    #expect(ElapsedText.precise(45) == "45s")
    #expect(ElapsedText.precise(194) == "3m 14s")
    #expect(ElapsedText.precise(3900) == "1h 05m")
  }

  @Test func aTimeIsMeasuredFromWhenTheStateBegan() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    #expect(ElapsedText.short(since: now.addingTimeInterval(-120), now: now) == "2m")
    #expect(ElapsedText.short(since: nil, now: now) == nil)
  }
}
