import Testing

@testable import MultishellHighlight

@Suite
struct SvelteGrammarInputTests {
  @Test func aGreaterThanAndABareAmpersandInTextBecomeSpaces() {
    #expect(SvelteGrammarInput.text(from: "<p>a > b & c &1 &#</p>") == "<p>a   b   c  1  #</p>")
  }

  @Test(arguments: [
    "<p>&amp; &lt &#62; &#x3E; &#X3e;</p>",
    "<a title=\"x > y\" alt='&' onclick={() => go(\"}\")}>z</a>",
    "<p class=\"a {b > c ? '\"' : d}\">e</p>",
    "<input {...rest} bind:value={a > b} />",
    "<!-- a > b & c -->",
    "<!DOCTYPE html>",
    "<a\n  href=\"x\">y</a\n>",
    "<script>a > b && c</script>",
    "<script lang=\"ts\">let a: Array<B> = c && d</sCrIpT>",
    "<style>a > b {}</style>",
    "{a > b && c}",
    "{#if a > b}x{:else if c > d}y{/if}",
    "{#each xs as x (x.id > 1)}<li/>{/each}",
    "{`${\"}\"}` > 1}",
    "{a /* } */ > b}",
    "{a // }\n > b}",
  ])
  func markupScriptsStylesCommentsAndExpressionsKeepTheirs(text: String) {
    #expect(SvelteGrammarInput.text(from: text) == text)
  }

  @Test func textAfterAnExpressionOrTagHoldingAClosingBraceInAStringIsStillBlanked() {
    let text = "{\"}\" > 1} > <p a={'}'}>&</p> > <script>x > y</script> >"

    #expect(
      SvelteGrammarInput.text(from: text)
        == "{\"}\" > 1}   <p a={'}'}> </p>   <script>x > y</script>  "
    )
  }

  @Test func aBackslashOutsideAStringEscapesNothingSoTheBraceAfterItEndsTheExpression() {
    #expect(SvelteGrammarInput.text(from: "{/\\}<p>></p>") == "{/\\}<p> </p>")
  }

  @Test func aBackslashInATemplateSubstitutionEscapesTheBraceAfterIt() {
    #expect(SvelteGrammarInput.text(from: "{`${a \\}`}<p>></p>") == "{`${a \\}`}<p>></p>")
  }

  @Test func anUppercaseScriptIsAComponentWhoseBodyIsMarkup() {
    #expect(SvelteGrammarInput.text(from: "<SCRIPT>a > b</SCRIPT>") == "<SCRIPT>a   b</SCRIPT>")
  }

  @Test func aSelfClosingScriptHasNoBodyToSkip() {
    #expect(SvelteGrammarInput.text(from: "<script /><p>></p>") == "<script /><p> </p>")
  }

  @Test func anUnclosedTagExpressionOrCommentRunsToTheEnd() {
    for text in ["<p a=\"> b", "{a > b", "<!-- > b", "<style>a > b", "{`${a > b"] {
      #expect(SvelteGrammarInput.text(from: text) == text)
    }
  }
}
