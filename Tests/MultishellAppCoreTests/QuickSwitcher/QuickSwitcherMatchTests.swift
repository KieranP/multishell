import Testing

@testable import MultishellAppCore

@Suite
struct QuickSwitcherMatchTests {
  private static func match(
    _ text: String,
    _ title: String,
    in location: String = "",
  )
    -> QuickSwitcherMatch?
  {
    QuickSwitcherMatch(QuickSwitcherQuery(text), title: title, location: location)
  }

  @Test func lettersInOrderThroughTheTitleMatchAndAreTheOnesBolded() throws {
    let match = try #require(Self.match("pbr", "Port block reuse"))
    #expect(match.titleOffsets == [0, 5, 11])
  }

  @Test func aWordNamedOutrightLaterInThePathBeatsItsLettersScatteredBeforeIt() throws {
    let match = try #require(Self.match("main", "multishell › main"))

    #expect(match.titleOffsets == [13, 14, 15, 16])
  }

  @Test func aBracketStartsAWordAsASpaceDoes() throws {
    let bracketed = try #require(Self.match("port", "fix (Port fix)"))
    let spaced = try #require(Self.match("port", "fix  Port fix"))

    #expect(bracketed.score == spaced.score)
  }

  @Test func lettersOutOfOrderDoNotMatch() {
    #expect(Self.match("rbp", "Port block reuse") == nil)
  }

  @Test func aLetterFoldingToTwoMatchesTheTwoAndBoldsItself() throws {
    let match = try #require(Self.match("strasse", "Straße"))

    #expect(match.titleOffsets == [0, 1, 2, 3, 4, 5])
    #expect(Self.match("ß", "Strasse") != nil)
  }

  @Test func caseAndAccentsAreIgnored() {
    #expect(Self.match("CAFE", "café menu") != nil)
  }

  @Test func aWordStartScoresAboveTheSameLettersMidWord() throws {
    let atStart = try #require(Self.match("re", "retry backoff"))
    let midWord = try #require(Self.match("re", "store"))
    #expect(atStart.score > midWord.score)
  }

  @Test func lettersFollowingOnScoreAboveLettersSpreadOut() throws {
    let together = try #require(Self.match("port", "fix-port-block"))
    let spread = try #require(Self.match("port", "pricing-order-test"))
    #expect(together.score > spread.score)
  }

  @Test func aWordMatchesTheStartOfAWordOfTheLocationWithNothingBolded() throws {
    let match = try #require(
      Self.match("billing", "Retry backoff", in: "Claude · billing-api › Webhook retries")
    )
    #expect(match.titleOffsets == [])
  }

  @Test func aLocationIsMatchedByWordStartsNotLettersScatteredThroughIt() {
    #expect(Self.match("port", "Retry backoff", in: "billing-api › webhook-retries") == nil)
  }

  @Test func aHyphenatedLocationNameMatchesWhole() {
    #expect(Self.match("billing-api", "main", in: "billing-api") != nil)
  }

  @Test func everyWordMustMatchSomewhere() {
    #expect(Self.match("retry billing", "Retry backoff", in: "billing-api") != nil)
    #expect(Self.match("retry site", "Retry backoff", in: "billing-api") == nil)
  }

  @Test func aWordNamedOutrightInTheLocationScoresAboveLettersScatteredThroughTheTitle() throws {
    let scattered = try #require(Self.match("api", "xaxpxi"))
    let named = try #require(Self.match("api", "xaxpxi", in: "billing › api"))

    #expect(named.score > scattered.score)
  }

  @Test func aTitleMatchOutscoresTheSameWordInTheLocation() throws {
    let inTitle = try #require(Self.match("api", "api", in: "billing"))
    let inLocation = try #require(Self.match("api", "main", in: "api"))
    #expect(inTitle.score > inLocation.score)
  }
}
