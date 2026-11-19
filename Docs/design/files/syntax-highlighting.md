# Syntax highlighting

How a file tab colours its text and why each went the way it did. Newest at the
bottom.

- **Highlighting is tree-sitter through SwiftTreeSitter, with a small runner of
  our own, not Neon**: the view is read-only, so a whole-file parse and one
  query, and one more of each per injection, is all it needs. About 54 ms for
  5,000 lines of Swift, off the main thread.
- **The committed side colours its removed rows alone**, its queries reading
  from its first removed row to its last and only the injections reaching one
  parsed: a 4,500-line Svelte file otherwise repeated every injection to colour
  one changed line. Its attribute scan begins at a tag opened above, so a
  repeated attribute stays a repeat. One cursor walks every run: a cursor each,
  800 runs in an 8,000-member class took 1.86 s in a release build, against 0.17
  s.
- **Spans become runs in text order off the main thread**: applied in pattern
  order, 202,607 of a 1 MiB file took 1.2 s on the main thread, the runs 70 ms.
- **Roles, not colours**: each capture is a role, each role a `file` key, so a
  theme recolours highlighting without knowing the grammars. `spell` is a spell
  checker's mark and colours nothing, and `constructor` is Swift's `init` but a
  class name elsewhere. CSS's `property` is a property or selector name and
  colours as an attribute; elsewhere it is a field and stays plain, as a
  variable does, SCSS's `$a` included.
- **The later pattern wins where one range carries several captures**, which is
  how the queries are written but for a few of CSS's and SCSS's. A query of ours
  read after theirs restates those: a custom property is a variable where
  defined and used, and a mixin's or function's name is a function. It also
  colours Svelte's `{:else if}`, which the grammar lexes as one token that the
  shipped query's `"else"` and `"if"` miss.
- **Each grammar is its own Swift package, fetched as its pinned commit's
  archive; its query ships in that package's resource bundle.** CSS's,
  JavaScript's, Python's and YAML's packages build without their scanners, so
  those four scanners, with what they include, are copied under
  `ThirdParty/tree-sitter/`.
- **The maintained repository over the most-starred one**, for YAML, TOML, Zig,
  Make, Svelte and SCSS, whose originals are archived or years stale.
- **A `<script>` or `<style>` body and a Svelte `{…}` expression are parsed in
  their own language**, each injection apart, and its spans follow the host's so
  they win inside it. The query that finds them is ours: Svelte's injection file
  is Neovim's and inherits one no package ships. In a release build a 4,500-line
  Svelte file with 4,050 injections took 155 ms, against 190 ms for 5,000 lines
  of Swift dense enough to give 130,000 spans. Reusing one parser a language
  saved about 50 ms of 0.7 s in a debug build. Joining a language's injections
  into one text, parsed and queried once, was tried: 7,500 took 216 ms against
  235 ms apart, too little for the fallback a joined text needs where one part's
  error, open comment or `//` runs into the next.
- **A script's or style's language follows what reads it**: in Svelte its
  `lang`, then its `type`; in HTML its `type` alone, HTML's `lang` naming a
  natural language. In Svelte a `text/scss` or `application/typescript` type
  stands for its `lang`, as svelte-preprocess 4 reads it; 5 and 6 read no type,
  but a project on 4 does. Svelte's preprocessors read attributes by regex: they
  take a type whole, match `lang` and `type` exactly in name and value with no
  space around the `=`, decode no character reference, and find every `<script>`
  and `<style>` with one regex, nested or not, whatever its type. HTML compares
  a script's type rid of ASCII whitespace and in any case, reads a JSON type
  without its parameters, a data block never running whatever they say, reads a
  `language` as `text/` and it untrimmed, compares a style's type untrimmed,
  decodes references in a value and keeps a repeated attribute's first value. A
  Less or indented Sass style stays plain, no grammar here reading it.
- **A Svelte expression is TypeScript where the compiler's `lang` regex first
  finds exactly `ts`, and JavaScript otherwise**, as Svelte's compiler decides
  it for the whole file: TypeScript reads `{a < b > (c)}` as a generic call
  where JavaScript compares. The regex is the compiler's own, run over the text
  rather than a reading of the tree's scripts, so it skips and takes what the
  compiler does, `data-lang="ts"` included. Each attribute of its second branch
  is matched atomically, `(?>…)`, where the compiler's backtracks exponentially
  over quoted attributes, on one line or several: nine indented ones took 1.5 s
  here before that and ten over 120 s, and node ran the compiler's own past 60 s
  at 40 on one line. The cost is one crafted tag,
  `<script x=">" a="b lang=ts" c>`, whose `lang` inside a value the compiler
  finds and this does not. A run of `<!--` or `<script` openings with no `-->`
  or `>` after them is still quadratic, as the compiler's is: 160 KB of
  `<script a ` took 41 s, where a real 1.8 MiB Svelte file takes 8.5 ms. An
  expression is read inside parentheses, which make `{a: 1}` an object, not a
  block holding a label. A block's pattern, an each's item or an await's value,
  is read as an arrow function's parameters instead, as `{ a = 1 }` parses there
  and as an object does not.
- **An inline `style` is CSS and an event handler JavaScript**, the style read
  inside `a{` and `}` so it parses as declarations. A handler is one of HTML's
  event names after `on`, its `webkit…` four or SVG animation's `begin`, `end`
  and `repeat`, so `one` or `onLabel` stays a string. In Svelte it sits on an
  element as Svelte's parser tells one from a component, `svelte:element`
  included: a component, a `<slot>` and another `svelte:` tag take `style` and
  `onclick` alike as string props or drop them, Svelte 4 dropping a string
  attribute on `svelte:window`, `document` or `body` and Svelte 5 rejecting it.
  A string handler is injected as Svelte 4 runs it, though Svelte 5 rejects one
  on any tag. An element's repeated `style` or `on…`, in any case, is injected
  as its first alone, as a browser keeps the first and Svelte 5 writes static
  attributes into a template the browser parses; Svelte 4 sets each in turn, the
  last winning. Blanking a stray `}` so it cannot close the `a{` changed no
  colour in any case tried, so it is not done. A `/*` left open at the end would
  swallow the closing `}`, so it is closed before it where that parses clean,
  CSS ending an open comment at the end of its input.
- **Only a `style` or `on…` attribute reaches the tree**: the text is scanned
  for those names and each is looked up in the tree directly. A query over the
  whole tree brought every attribute back to Swift, tree-sitter's runtime
  evaluating no predicate. On a 20,000-line file of 80,000 other attributes,
  finding injections took 157 ms of a 507 ms highlight in a release build, and
  now 45 ms of 408 ms, all but 2 ms the query for scripts and styles. A file
  with a handler on every line spends 124 ms finding its 40,000; the lookups
  alone take 42 ms, tree-sitter holding long runs of siblings in balanced hidden
  nodes, so a parent is no linear walk. A `TreeCursor` pass over the 80,000
  attributes' tree took 38 ms, the scan and its lookups 3. A value holding a
  Svelte expression keeps its string colour, CSS breaking around one.
- **An attribute's references are decoded as HTML decodes them** before it is
  parsed, so `&amp;&amp;` reads as `&&`, each span mapping back over the whole
  references it covers: numeric references and HTML's names for ASCII
  punctuation, `&Tab;`, `&NewLine;` and `&nbsp;`, the legacy `&amp`, `&lt`,
  `&gt`, `&quot`, `&nbsp` and their capitals needing no `;` unless a letter,
  digit or `=` follows, `&#0;` and numbers past Unicode as U+FFFD, and `&#128;`
  to `&#159;` as windows-1252. HTML's other 2,000 names stay as written.
- **An injection starts from a plain span**, so no host colour shows between its
  tokens, unless its grammar would not compile or its parser refuses it, when
  the host's colour stays. The view paints runs flattened from every span, so a
  plain span costs no second paint, and a plain span clears what it covers and
  leaves no run, so a removed row keeps its dimmed text.
- **A query that fails to compile costs its own colours only**: a failed
  injection query leaves the file its host colours rather than failing the whole
  grammar, and a grammar that would not compile is tried again on the next
  highlight, so one read that fails while `make install` replaces the bundle
  costs a single highlight. Two highlights needing one grammar compile it once;
  the lock is held only to read and set it, not for the compile's 100 ms.
- **A Svelte block head is cut where its grammar leaves it one piece of text**:
  `{#each xs as x, i (x.id)}` reads its key apart, `{#await p then v}` colours
  `then` or `catch` itself, and `{#snippet row(a: number)}` is read as
  `function row(a: number) {}`. `then` is a legal name, so it is the keyword
  only after a finished expression, `f()then v` included, and before a space and
  a name, a pattern or the end, as Svelte's own parser requires:
  `ready ? then : other` and `typeof then` are one promise, `p! then v`,
  `i++ then v`, `api.new then v` and `p as Promise<X> then v` two parts, a
  generic's `>` having no space before it. A `/` starts a regex wherever an
  expression has not just ended, so `a!/2` and `{}/2` divide and `return /(/`
  starts a regex. A regex scan that reaches the line end unclosed records where
  it passed, so a later `/` stops there: 32,000 units of `[ / ` took 13.4 s
  without it in a debug build, and 36 ms with it.
- **The block-head cuts are a scanner of our own, not a TypeScript parse**: a
  head is no valid TypeScript, and its parse puts the error where recovery
  lands, not where the promise ends. `sum(a!/2) + b/2 then v` folds `then` into
  the last division, `p as Promise<X> then v` into the `as`, and
  `item, i (item.id)` reads as a call to `i`, the very key the cut finds.
- **Svelte's grammar is given its file with each `>` and bare `&` in text
  content a space**: its text token refuses both, as HTML's does, though HTML
  allows them, and where HTML's recovery drops a word, Svelte's, a few lines on,
  makes the rest of the file one error, its tags and style uncoloured. The
  length stays, so every range is the file's. Neither grammar's main branch
  fixes it, and patching one means vendoring its generated parser. The pass took
  85 ms of a 1.8 s debug highlight of 2.3 million units.
- **A Markdown fenced code block is parsed in the language its info string
  names**, by name, extension or interpreter in any case. A PHP fence not
  starting `<?` is read after a `<?php ` of our own, the grammar otherwise
  reading it all as HTML. A Markdown fence keeps Markdown's colour, as each
  fence in it would be injected a level deeper, and 200 nested overflowed a
  worker thread's stack. A quote's `>` markers and a list item's indent are
  parsed as spaces on every line of a fence, YAML otherwise reading a `>` as a
  folded scalar and a line indented past the first as nested; Python then reads
  its first line as indented and recovers, `def` and `return` still coloured.
  The grammar closes no fence on a last line with no newline after it, so
  Markdown is parsed with one added.
- **A Markdown file's HTML blocks are parsed together as one HTML document**,
  the Markdown between them blanked. `<details>`, a blank line, Markdown and
  `</details>` make two blocks, and the second alone is an error to HTML's
  grammar; together they read as the rendered page does. Blanking the 6,167
  stretches between blocks of a 1 MiB file took 8 ms of a debug highlight whose
  run to run spread was over a second. Every block is read when a diff colours
  only removed rows, so a closing tag there meets its opener above.
- **A heading tag that opens a paragraph is read as an HTML block**: the grammar
  reads a block tag's name as letters alone, upstream as at our pin, so
  `<h1 align="center">Multishell</h1>` is a paragraph to it, and runs into the
  paragraph above when no blank line comes between. Where CommonMark would start
  a block at `<h1>` to `<h6>`, the paragraph is HTML from that line to its end.
  The tags are found by searching the text for `<` and looking up the paragraph
  around each hit: capturing every paragraph instead cost 7% of finding a 1 MiB
  file's injections. Each paragraph and its markers are read once: read again
  for each mention, a quoted paragraph naming `<h1>` on each of 10,000 lines ran
  past four minutes in a debug build, and takes a second now. A mention walks
  back over its indent and its line's marker alone: one line of 64,000 mentions
  ran past a minute walking back to the line's start, and takes a second and a
  half now. A mention in a fence or HTML block skips that block whole: looked up
  one by one, a fence of 30,000 `<h1>` lines took 0.43 s.
- **Processing instructions and CDATA stay Markdown's**, HTML's grammar reading
  `<?…?>` and `<![CDATA[…]]>` as tags. Only the block grammar is parsed, so HTML
  within a paragraph, `Run <kbd>make</kbd>`, and inline code stay Markdown's.
- **A language is picked by extension, then by name where the extension says
  nothing, then by shebang.** The shebang is the file on disk's, which a unified
  diff lists after `HEAD`'s first line.
- **An interpolation's `@embedded` or `@none` is a hole, not a span.** In
  pattern order its plain span erased the code's own colours inside a template
  literal, an f-string or `"$(date)"`; it is cut out of the spans around it.
- **Zig's `#lua-match?` is rewritten as `#match?`**, its patterns using no `%`:
  SwiftTreeSitter passes every match of a predicate it does not know. A `@_`
  capture feeds a predicate and colours nothing.
- **`#is-not? local` is answered from the names the grammar's locals query
  declares**, file-wide rather than per scope: answered no, every bare Ruby name
  read as a call and a JS local named `console` as the built-in. Only the
  definitions are queried, the reference pattern matching every name; a 1 MiB JS
  file took 4.60 s against 4.12 s in a debug build.

## Reviewed and left as is

Raised by reviews and settled; a review need not raise these again.

- **A fence closed where CommonMark would not.** The Markdown grammar closes a
  fence on a closer indented four spaces, and on an unquoted line of `>` and a
  fence. The injection follows the grammar so the code's colours and Markdown's
  agree; rules of our own over its last line were tried and dropped.
- **A fence indented one to three spaces keeping that indent in its code.**
  CommonMark strips it; tried with Python, `def` and `return` still colour.
- **Quote markers re-coloured from the host's own spans.** Those spans are the
  markers' nodes exactly, and the filter runs only where a fence or HTML block
  is quoted or in a list, a blank line's empty marker dropped. Leaving the
  markers out of the plain span and the injected spans would split both around
  every marker.
- **Every GitHub alias.** The common names are listed; rarer ones such as
  `shell-script` or `xhtml` are not.
- **A private helper in `HighlightInjections.swift`.** A private function stays
  in its type's file, as `body(of:)` does; a helper type gets its own.
- **`lineFeed` kept in `SyntaxHighlighter` rather than `ASCIIUnits`.**
  `ASCIIUnits` holds the units more than one scanner compares; this has one
  reader.
- **Fences filtered by kept ranges in `HighlightInjections.find` as well as in
  `SyntaxHighlighter`.** `find` returns only the injections that may reach a
  kept range, which FencedCodeBlockTests holds it to; the highlighter's filter
  covers every injection, the combined HTML one included.
- **A heading-tag block ending where the grammar ends its paragraph.**
  CommonMark runs `<h1 a>T</h1>` on to the next blank line, so a `# Next` or
  `---` straight under it is HTML; here it keeps Markdown's colour. Matching it
  means changing `iswalpha` to accept digits in the name loop of the Markdown
  scanner's HTML block start, which our pin and upstream main share: one line,
  but a patch to carry on every grammar bump, so it was not made.
- **A quoted or listed HTML block followed by a blank line and more of the quote
  or item left plain.** Markdown's grammar parses it as an error, not an
  `html_block`; reading it would mean patching the grammar.
- **`"makefile"` in both `byCodeFenceName` and `byFileName`.** `byFileName`
  matches a file's name in its own case; a fence's name is folded, so reading it
  there would take `.bashrc` or `brewfile` as fence names by accident.

### Asked both ways

- **One tuple type for a paragraph's range and markers and an HTML block's**:
  round 7 of the Markdown HTML review asked for `HTMLBlocks.Block` in place of a
  same-shaped `ParagraphLines`; round 9 asked for them apart again. Kept as one,
  since both are a range and the markers blanked in it, and named the function
  that builds the paragraph's `rangeAndMarkers(of:)`.
