# The Files panel and file tabs

What the panel lists, what a file tab shows and why each went the way it did.
Newest at the bottom.

- **A panel beside the tab area, not a cover over it nor a list beside a diff.**
  A 400 pt diff was too cramped, and a cover hid the agent being reviewed.
- **One tab per file, its changes drawn inside it.** The user reads a file and
  its change as one thing, so there is no diff tab and no Show Diff button.
  Opening a file already open turns to its tab; there is no preview tab.
- **Uncommitted changes, and since the base branch**: see Modified and Branch at
  the bottom.
- **Read-only.** Editing is the editor's job, a click away in each menu.
- **The panel lists every file, and git says how each looks.** Tracked files
  come from the index, new ones from the status read's list, and what git
  ignores lists greyed. A folder git ignores whole is one entry, so
  `node_modules` costs a row, and it is listed from disk one level at a time as
  it opens. Cost: an empty folder is not listed, git never naming one.
- **What git ignores is read one at a time, the next waiting ten times the last
  one's cost and the listing rebuild it set off**, a second at least: an install
  or a build writes there constantly, and rebuilding after every read held half
  a core for a whole build. Capped at 50,000 entries, with no footer saying so
  past it. An opened ignored folder and an expanded submodule are each paced the
  same way, and a listing too large for a render builds one at a time, since a
  started build cannot be stopped.
- **The index, not `ls-files --cached --others`.** The second walks the tree
  again, 198 ms on Linux's 96,000 files against 27 ms, and prints untracked
  paths first, so a cap would let `node_modules` push tracked files out. Capped
  at 200,000 tracked paths, the footer saying so past it.
- **New files are counted whole and drawn up to 50,000.** A cap on what is
  counted would make the panel disagree with the badge; drawing is the cost. The
  footer names the rest.
- **One per-file list feeds the badge, its tooltip, the removal dialog, the
  command line and the panel**, for every worktree, panel open or not, so no two
  can disagree; worktrees.md has the read.
- **Glyph tabs named in a tooltip, Files, Changes, PR and CI**, not a lettered
  toggle, "M 4" not saying what it was. Changes is a document with a diff: a
  branch glyph beside the pull request's arrow read as two of the same. The
  tooltip is drawn in the theme, `.help`'s being the system's grey. No count on
  the switch, the footer carrying it, and no status letters anywhere: the counts
  and the dot carry the change.
- **Files or Changes is one choice for every worktree, kept with the settings**
  under the `all` and `modified` earlier builds wrote, so an older build still
  reads it; the command line says `files` and `git`, `modified` being a scope,
  as Unified or Split is, so a relaunch or another worktree lists what the last
  panel did. A click on a row's git badge sets it to Changes under Modified.
- **A zero side of a file's count is left out**, `+21 −0` on a new file reading
  as noise. The sidebar badge and the footer keep both, a badge changing shape
  having read as broken.
- **Changes merges single-child folders**, `Tests/AppCoreTests/Detail` one row,
  and starts open where Files starts shut.
- **The filter folds as the sidebar's does**, over the whole path, matched as
  UTF-8 over paths folded and composed once: `contains` took 181 to 263 ms over
  200,000 paths, a byte search 7 to 11.
- **The panel is one switch for the window, shut at each launch, and its width
  is per machine**, kept as the sidebar's is. A switch kept across launches
  opened the panel with the first worktree, which read as a bug. The model holds
  the switch, so a click on a row's badge can open it. Double-clicking either
  edge resets its width. No keyboard shortcut yet; a View menu item.
- **Both clamps leave the tabs one minimum**, so a wide sidebar beside a wide
  panel cannot squeeze the tabs to nothing.
- **A click on a row's git badge opens the panel on Changes under Modified**,
  what the badge counts, with a named accessibility action on the row, whose
  children VoiceOver cannot reach.
- **A file opens in a tab by the clicked-link rule**: a regular file typed as
  text or whose start reads as text. A file gone from disk is judged on git's
  copy. A link inside the worktree opens the file it points at, git diffing a
  link as the path it holds; one leading out, and anything else, beeps.
- **Copy Path copies the absolute path**, as the worktree's own does.
- **No drag out of the panel**, the app's drags carrying its own pasteboard
  types; a file URL would let Finder move the file.
- **The panel's worktree is read in the background while its window shows**, so
  coming back never shows a stale list. Other rows keep the frontmost-only
  reads.
- **The tree's listing is built again only when paths move**, not for a count,
  as an agent's every save moves one: 200,000 paths took 1.2 s. Past 20,000 it
  builds off the main actor, the last listing drawn meanwhile. Each path is
  folded once for the filter, which folding them all per keystroke made 0.9 s. A
  modified file's first edit moves no path, the index holding it. The changed
  paths' half is kept while only counts move too: 50,000 new files took 0.3 s
  per status read. Past 20,000 changed paths it builds off the main actor as
  well, as a tracked file changing moves the set without moving the listing. The
  listing's bound counts every path it lists, a read submodule's and a staged
  deletion's included. What a status read still costs the main actor, the tree's
  kinds and counts and the shown rows, stays there by choice: 110 ms at 100,000
  changed paths and 300 ms at 250,000, at most once in 10 s.
- **Only the panel's own worktree keeps its listing**, and the selected one's
  while the quick switcher is up, a Linux-sized one and its tree holding about
  80 MB; coming back reads it again, with each open folder git does not list. A
  folder git stops ignoring drops what was read of it.
- **File tabs are a type of their own beside terminal tabs**, one order per
  group covering both. A tab holding a file would promise a pane tree it has not
  got.
- **The order is written into each group, and `tabs` kept in step**, so an older
  build reads its terminal tabs in the order this one drew them. It drops file
  tabs, under a key it ignores.
- **A file tab persists, its scroll saved at quit; its contents do not.** After
  a relaunch a deleted file's tab shows `HEAD`'s text removed, as opening it
  from the panel does, and the missing notice only where git never had the file.
- **A file tab never leaves its worktree**, a file belonging to the worktree it
  was opened in, so a drop on another row is refused and the row lights nothing.
- **A worktree holding only file tabs gets no automatic shell**, at launch or
  after.
- **The split buttons disable on a file tab rather than hide**: hiding them
  changed the strip's button width, and every tab resized on a switch.
- **No rename, and the tab is titled by the shortest trailing path that tells it
  from another open file of its name**: `models/user.rb` beside `lib/user.rb`.
- **A deleted file's tab stays, struck through, with the last text it read**,
  until the user closes it, as Zed does; a hidden tab whose file is gone keeps
  its rows for this.
- **A rename is a file gone and a file added**, renames being off everywhere, so
  the old path's tab becomes a deleted file's.
- **The tab shows the file on disk against `HEAD` whatever the indicator says**,
  staged changes drawn hollow in the gutter and unstaged filled, as Zed does.
  Neither Zed nor VS Code has a staged-only view. Cost: under Staged Only a
  tab's counts can differ from its row.
- **Staged lines are found by diffing the index too, with the same algorithm**,
  or one edit splits into different hunks and no line matches.
- **The tab's diff uses the badge's algorithm**, so the two count an edit alike.
- **A tab re-reads on its folder's events where its `lstat` moved, and on its
  project's git changes**, ahead of the frontmost and ignored-folder guards: the
  window is often beside the editor making the change, and a tracked file can
  sit forced in under an ignored folder. By directory, FSEvents' file flags
  lingering for seconds.
- **A hidden tab is owed its read until shown**, but a deletion strikes its
  title at once, the strip showing it.
- **A hidden tab lets go of its rows**, keeping its corner dot and strike, so
  content nobody sees holds no memory: a 1 MiB file's rows are several copies of
  its text. A read waiting for it is owed instead, the reads it would cost being
  for nothing. Shown again it is read at once, not at its pace. Cost: its body
  and bar's counts are blank until that read lands, and a file deleted after its
  tab was hidden shows `HEAD`'s text removed, or the missing notice where git
  never had it, as after a relaunch.
- **A 75 ms settle and a pace of ten times the last re-read's cost**, so a save
  shows in about a quarter second and an agent rewriting a file in bursts costs
  at most a tenth of a core. A change during a read reads once after it.
- **A file tab is capped at 1 MiB, on disk and in `HEAD`.** git diffs 1 MiB in
  under 40 ms, but the forced view takes up to 186 MB laid out at that size.
  `HEAD`'s size is asked first, so a small file whose last commit is huge never
  diffs into memory. A line is cut at 10,000 characters, a 1 MiB file being able
  to be one line.
- **Text is UTF-8, else the encoding a text editor would guess**, the open rule
  admitting any text-typed file; the diff is decoded the same way, git copying
  the file's bytes into it.
- **The view is TextKit 2 with every row's frame forced**, the user preferring
  Apple's current engine. Plain TextKit 2 estimates the height of rows it has
  not laid out: split sides drifted 787 to 3,435 rows apart and
  `scrollRangeToVisible` missed 10 of 10 targets. One override of
  `layoutFragmentFrame` made it exact.
- **That override is not a documented point**, so the drift tests lay out about
  10,750 rows and jump to the end first, then check the rows on screen at nine
  jumps, and the split's two offsets; they fail at once with it removed. TextKit
  1 with contiguous layout, exact too, is the fallback. Cost: up to 186 MB fully
  laid out at 1 MiB against TextKit 1's 30, which is why a hidden tab drops its
  layout. Its scroll is kept in the model by the file's line at the top, Unified
  and Split putting one line on different rows, taken back once the new view has
  a size, and saved with the tab at quit: written on each scroll, the workspace
  would save and redraw dozens of times a second. A crash loses what moved since
  the last quit.
- **A file tab has its own font and size**, in Settings > Appearance beside the
  terminal's, not the UI size less one: code read at the UI's size was too small
  for some and too large for others. A change rebuilds the view, the rows'
  geometry being built from the font.
- **The rows the geometry puts in view are laid out before TextKit looks for its
  top row.** It finds that row by its own estimate and lays out every row
  between there and the forced one: a jump to the middle of a 1 MiB file took
  170 ms, against 24 ms for stock TextKit 2, and takes 24 ms with this.
- **No soft wrap**, split rows holding one height only where neither side wraps.
- **The tints are painted behind the text, edge to edge.** The base themes take
  Claude Code's diff colours, so a diff reads the same in a file tab as in the
  agent beside it: its dark terminal theme's, and the light ones sampled from
  its diff view. Cost: on the dark base, green strings on the added green lose
  contrast, which lighter tints once avoided.
- **The words a changed line differs in are painted darker over its tint.** A
  run of removed lines and the added run after it are diffed by word as one
  text, every run of spaces and newlines one token, so a rewrap's moved words
  and breaks still match; pairing line with line marked a rewrapped paragraph
  nowhere. A run sharing under half of its shorter side is a rewrite and marked
  nowhere, judged on the shorter so a line edited with new lines after it is
  still an edit. A line changed whole keeps only its tint. A run too costly to
  diff whole, a few hundred rewritten lines, is paired line with line instead.
- **The gutter is a plain view, not `NSRulerView`**, which on macOS 26 drew into
  a view as tall as the document and went stale across programmatic scrolls.
- **The file view clips to its frame.** Views no longer clip by default, and
  TextKit 2 asks for a background over more than the view shows: unclipped, it
  painted over the header, the tab strip and the bar.
- **A selection touching a change copies as `git diff` prints it**; a split side
  copies plain text. Copy, a drag and Services share one override.
- **Find is the app's own floating bar**, appearance.md having ruled out a find
  strip; a file tab is searched in the model, the engine searching only panes.
- **Find's matches are painted under the text with the line tints**, not as
  TextKit 2 rendering attributes, which marked none of its line views for
  drawing: a search typed into the bar showed its matches only at the next
  scroll.
- **Only a new find text or a step moves the selection**, counted in the model:
  a re-read keeps the nearest match, but matches found above it shift its index.
  A layout switch carries the selected match by the file's line, not its text:
  Unified's removed rows shift where repeated lines sit. A rebuilt view selects
  the match but returns to its saved scroll, which the user may have moved off
  the match, unless a search or step came since it was last drawn.
- **A Changes rotor walks the changed lines**, the text's attributes carrying no
  sign of an addition.
- **A file tab's memory is labelled in Debug Info**, estimated from the text it
  keeps, rather than left in the app's row.
- **Split is offset-locked**, the same offset being the same row on both sides
  under the forced geometry; a lock by row left the scrollers thousands of
  points apart.
- **Unified or Split is one choice for every tab, kept with the settings**, so
  the next file opens as the last was read. A file only added to or only removed
  from stays Unified and offers no switch: one side would be blank.
- **Highlighting is tree-sitter through SwiftTreeSitter, with a small runner of
  our own, not Neon**: the view is read-only, so a whole-file parse and one
  query, and one more of each per injection, is all it needs. Two parses, the
  file on disk and `HEAD`'s text, each side's ranges mapped onto its rows. Where
  both are parsed `HEAD`'s colours its removed rows alone, so its queries read
  from its first removed row to its last and keep what meets one, and of its
  injections only those reaching one are parsed, a 4,500-line Svelte file
  otherwise repeating every injection to colour one changed line. A cursor for
  each run walked the tree again each: 800 runs in an 8,000-member class took
  1.86 s in a release build, against 0.17 s for one cursor over them all. Its
  attribute scan begins at a tag opened above one so a repeated attribute stays
  a repeat; a Svelte file's `lang` is read from the whole text by the compiler's
  own regex. About 54 ms for 5,000 lines of Swift, off the main thread. The
  spans become runs in text order there too: applied in pattern order, 202,607
  of a 1 MiB file took 1.2 s on the main thread, the runs 70 ms.
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
  is Neovim's and inherits one no package ships. One parser a language serves a
  whole file. In a release build a 4,500-line Svelte file with 4,050 injections
  took 155 ms, against 190 ms for 5,000 lines of Swift dense enough to give
  130,000 spans, where the 54 ms above is lighter Swift. Reusing the parsers
  saved about 50 ms of 0.7 s in a debug build. Joining a language's injections
  into one text, parsed and queried once, was tried: 7,500 took 216 ms against
  235 ms apart, too little for the fallback a joined text needs where one part's
  error, open comment or `//` runs into the next.
- **In Svelte a script's language is its `lang`, then its `type`; in HTML its
  `type` alone**, HTML's `lang` naming a natural language. In Svelte a
  `text/scss` or `application/typescript` type stands for its `lang`, as
  svelte-preprocess 4 reads it; 5 and 6 read no type, but a project on 4 does.
  Its regex takes the type whole, so `text/scss; charset=utf-8` or
  `text/typescript ` names no preprocessor. A name it does not know,
  `text/babel`, is read as HTML reads it. `ts` is TypeScript, Babel's and JSX's
  types JavaScript, JSON-LD and import maps JSON, a template type nothing; a
  script with no `type` but a `language` is read as `text/` and that language,
  as HTML reads it. A script's type is compared as HTML compares it, rid of
  ASCII whitespace and in any case but whole, so
  `text/javascript; charset=utf-8` or a type of only spaces is a data block and
  stays plain; a JSON type is read without its parameters, a data block never
  running whatever they say; a `language` is read as `text/` and it untrimmed,
  and a style's type is compared untrimmed, as browsers compare it. Svelte reads
  a top-level script or style whatever its type, so there a type loses its
  parameters and spaces first and `language` is ignored. That holds for one
  nested in markup too, as Svelte's `preprocess` finds every `<script>` and
  `<style>` with one regex, nesting aside. A repeated attribute keeps its first
  value, and a value's character references are decoded first,
  `text&#47;javascript` being JavaScript, in HTML only: Svelte's preprocessors
  read attributes by regex and decode none. They match `lang` and `type` exactly
  too, names and values, so `LANG="ts"` is JavaScript there and `lang="TS"` no
  language, where HTML reads a name in any case. Their regexes take `lang=` and
  `type=` with no space around the `=`, so `lang = "ts"` names none there. A
  style's `lang="scss"` is SCSS; a Less or indented Sass style stays plain, no
  grammar here reading it.
- **A Svelte expression is TypeScript where the compiler's `lang` regex first
  finds exactly `ts`, and JavaScript otherwise**, as Svelte's compiler decides
  it for the whole file: TypeScript reads `{a < b > (c)}` as a generic call
  where JavaScript compares. The regex is the compiler's own, run over the text
  rather than a reading of the tree's scripts, so it skips a commented-out
  `<script`, `<SCRIPT` and a `lang` value it cannot match such as `"ts x"`, and
  takes `data-lang="ts"`, as the compiler does. Each attribute of its second
  branch is matched atomically, `(?>…)`, where the compiler's backtracks
  exponentially over quoted attributes, on one line or several: nine indented
  ones took 1.5 s here before that and ten over 120 s, and node ran the
  compiler's own past 60 s at 40 on one line. The cost is one crafted tag,
  `<script x=">" a="b lang=ts">`, whose `lang` inside a value the compiler finds
  and this does not. A run of `<!--` or `<script` openings with no `-->` or `>`
  after them is still quadratic, as the compiler's is: 160 KB of `<script a `
  took 41 s, where a real 1.8 MiB Svelte file takes 8.5 ms. An expression in
  either language is read inside parentheses, which make `{a: 1}` an object, not
  a block holding a label. A block's pattern, an each's item or an await's
  value, is read as an arrow function's parameters instead, as `{ a = 1 }`
  parses there and as an object does not. A shorthand attribute,
  `<input {value}>`, keeps its attribute colour.
- **An inline `style` is CSS and an event handler JavaScript**, the style read
  inside `a{` and `}` so it parses as declarations. A handler is one of HTML's
  event names after `on`, its `webkit…` four or SVG animation's `begin`, `end`
  and `repeat`, so `one` or `onLabel` stays a string, and in Svelte it sits on
  an element: a tag neither dotted nor starting with an uppercase letter, as
  Svelte's parser tells a component, nor `slot`, or `svelte:element`. A
  component, a `<slot>`, and another `svelte:` tag take `style` and `onclick`
  alike as string props or drop them: Svelte 4 drops a string attribute on
  `svelte:window`, `document` or `body`, and Svelte 5 rejects it. A string
  handler is injected as Svelte 4 runs it, set as an attribute, though Svelte 5
  rejects one on any tag. An element's repeated `style` or `on…` is injected as
  its first alone, as a browser keeps the first, so a bare first `onclick`
  leaves a later one a string. A repeat in another case counts too, Svelte 5
  writing static attributes into a template the browser parses; Svelte 4 sets
  each in turn, the last winning. Invalid CSS in a `style` colours as the CSS
  grammar's error recovery reads it: blanking a stray `}` so it cannot close the
  `a{` changed no colour in any case tried, so it is not done. A `/*` left open
  at the end would swallow the closing `}`, so it is closed before it where that
  parses clean, CSS ending an open comment at the end of its input; a `/*` in a
  string parses clean already and is left alone.
- **Only a `style` or `on…` attribute reaches the tree**: the text is scanned
  for those names, bare or not, and each is looked up in the tree directly, its
  node then its attribute and tag. A query over the whole tree brought every
  attribute back to Swift, tree-sitter's runtime evaluating no predicate. On a
  20,000-line file of 80,000 other attributes, finding injections took 157 ms of
  a 507 ms highlight in a release build, and now 45 ms of 408 ms, all but 2 ms
  the query for scripts and styles. A file with a handler on every line spends
  124 ms finding its 40,000; the lookups alone take 42 ms, tree-sitter holding
  long runs of siblings in balanced hidden nodes, so a parent is no linear walk.
  A name follows anything that cannot be part of one, `{...rest}onclick`
  included, and is a handler only for one of the events above. The scan is not a
  walk of the tree's attribute names: a `TreeCursor` pass over the 80,000
  attributes' tree took 38 ms, the scan and its lookups 3. A value holding a
  Svelte expression keeps its string colour, CSS breaking around one. An
  attribute's numeric references and HTML's names for ASCII punctuation,
  `&Tab;`, `&NewLine;` and `&nbsp;` are decoded before it is parsed, `&quot;` to
  `"`, `&amp;&amp;` to `&&` and `&lpar;` to `(`, and each span maps back over
  the whole references it covers; HTML's other 2,000 names stay as written. As
  in HTML, `&amp`, `&lt`, `&gt`, `&quot` and `&nbsp`, and the capital `&AMP`,
  `&LT`, `&GT` and `&QUOT`, need no `;` unless a letter, digit or `=` follows,
  so `&ampx` stays as written; `&#0;` and numbers past Unicode are U+FFFD, and
  `&#128;` to `&#159;` are windows-1252. A value with no `&` is not decoded. An
  injection starts from a plain span, so no host colour shows between its
  tokens, unless its grammar would not compile or its parser refuses it, when
  the host's colour stays. A script or style body takes one too: the view paints
  runs flattened from every span, so a plain span under its tokens costs no
  second paint. A plain span clears what it covers and leaves no run, so a
  removed row keeps its dimmed text, as it does in a file of the injected
  language. An injection query that fails to compile is logged and leaves the
  file its host colours, rather than failing the whole grammar. A grammar that
  would not compile is tried once a highlight and again on the next, so one
  query read that fails while `make install` replaces the bundle costs a single
  highlight. Two highlights needing one grammar compile it once, the second
  waiting for the first; the lock guarding it is held only to read and set it,
  not for the compile's 100 ms.
- **A Svelte block head is cut where its grammar leaves it one piece of text**:
  `{#each xs as x, i (x.id)}` reads its key apart, `{#await p then v}` colours
  `then` or `catch` itself, and `{#snippet row(a: number)}` is read as
  `function row(a: number) {}`. The cuts skip what brackets and quotes hold.
  `then` is a legal name, so it is the keyword only after a finished expression,
  `f()then v` included, and before a space and a name, a pattern or the end, as
  Svelte's own parser requires: `ready ? then : other` and `typeof then` are one
  promise, `p! then v`, `i++ then v`, `api.new then v` and
  `p as Promise<X> then v` two parts, a generic's `>` having no space before it.
  Comments are skipped, as are regexes, a `/` starting one wherever an
  expression has not just ended, so `a!/2` and `{}/2` divide, `return /(/` and
  `if (a) /(/` start a regex, and neither a `'` nor a `//` inside one misleads;
  a quote still left open reads the head again with quotes as plain text. A
  regex scan that reaches the line end unclosed records where it passed, so a
  later `/` stops there: 32,000 units of `[ / ` took 13.4 s without it in a
  debug build, and 36 ms with it. The query names each place a `{…}` sits, so a
  Svelte expression needs no parent lookup.
- **Svelte's grammar is given its file with each `>` and bare `&` in text
  content a space**: its text token refuses both, as HTML's does, though HTML
  allows them, and where HTML's recovery drops a word, Svelte's, a few lines on,
  makes the rest of the file one error, its tags and style uncoloured. A `&`
  starting no reference the grammar knows is bare, `&1` and `&#` too. The length
  stays, so every range is the file's, and queries and injections read the file
  itself. The tags, comments, script and style bodies and `{…}` expressions
  skipped on the way are found as its scanner finds them, an expression's
  strings, templates and comments hiding their braces. Neither grammar's main
  branch fixes it, and patching one means vendoring its generated parser. The
  pass took 85 ms of a 1.8 s debug highlight of 2.3 million units.
- **The block-head cuts are a scanner of our own, not a TypeScript parse**: a
  head is no valid TypeScript, and its parse puts the error where recovery
  lands, not where the promise ends. `sum(a!/2) + b/2 then v` folds `then` into
  the last division, `p as Promise<X> then v` into the `as`, and
  `item, i (item.id)` reads as a call to `i`, the very key the cut finds.
- **A Markdown fenced code block is parsed in the language its info string
  names**, its first word read in any case by name, extension or interpreter:
  `sh`, `shell`, `Python`, `python3`, `c#`. A fence naming no grammar here, or
  none, keeps Markdown's colour. A Svelte fence is given its grammar as a Svelte
  file is, and a PHP fence not starting `<?` is read after a `<?php ` of our
  own, the grammar otherwise reading it all as HTML. A Markdown fence keeps
  Markdown's colour, as each fence in it would be injected a level deeper, and
  200 nested overflowed a worker thread's stack. A quote's `>` markers and a
  list item's indent are parsed as spaces on every line of a fence, the first
  included, YAML otherwise reading a `>` as a folded scalar and a line indented
  past the first as nested; the markers keep the quote's colour. Python then
  reads its first line as indented and recovers, `def` and `return` still
  coloured. The grammar closes no fence on a last line with no newline after it,
  so Markdown is parsed with one added. An HTML block and inline code stay
  Markdown's.
- **A language is picked by extension, then by name where the extension says
  nothing, then by shebang.** `Rakefile` and `Gemfile` are Ruby by name, and
  `Cargo.lock` TOML, `Package.resolved`, `.prettierrc` and `.swift-format` JSON.
  The shebang is the file on disk's, which a unified diff lists after `HEAD`'s
  first line.
- **A submodule's folder opens as a repository of its own**, listed and read
  apart, since the worktree's git lists the folder and nothing in it. Its rows
  carry their own counts but stay out of the worktree's Changes list, which is
  what the worktree would commit, and a file tab inside it diffs against the
  submodule's `HEAD`. One nobody has initialised lists empty: `git -C` there
  runs against the parent, so `rev-parse --show-toplevel` must name the folder.
- **A new file git ignores shows as it is**, not every line added: the badge and
  the panel count it as no change.
- **Find in a split searches its right side**, the file on disk, the left being
  what the file was.
- **A saved file tab whose path leaves its worktree is dropped on load**, as is
  one whose id another tab holds or whose path another tab shows: a hand edit
  could otherwise point a tab anywhere.
- **Arrows in a file tab's bar step from change to change**, drawn wherever a
  line changed, in a segment well as the Unified / Split switch is, up before
  down as the find bar has them. A change is a run of rows other than context, a
  split side's padding included, so a removal is a stop in either layout. A step
  counts from the selection where it is in view and from the first row in view
  otherwise, as an editor counts from its cursor: a scroll by hand then a step
  lands below what was read, not back at the top. It leaves the selection at the
  change so the next step counts on from there, and keeps the column scrolled
  sideways to, as a restore does. A split steps from the side holding the
  keyboard, a step from the right having ignored a click on the left.
- **Steps stop at either end and the arrow with nowhere to go greys out**, the
  user's choice over wrapping as find does. The view reports which ways are open
  as it scrolls and its selection moves, the bar not knowing either; the change
  starts are kept with the rows, so that is a halving per scroll, not a walk of
  the file.
- **The change a step lands on is boxed** until the caret leaves it, so with
  several in view the box shows which one the next step counts from, and a split
  boxes both sides. It is held by the `HEAD` lines it replaces, or for a change
  only adding lines the gap it fills, since `HEAD`'s numbering moves with no
  edit: a change still sharing one of those lines, spanning that gap, or only
  adding lines where those stood is the same change, the one sharing most where
  several do, its first line edited or reverted or grown upward; one replacing
  only a line beside it is not. Lines left where a replaced line was reverted
  read the same as a line typed beside it, and either way the box stays on rows
  the old one touched. Only a commit or checkout moves `HEAD`'s numbering, which
  shows as `HEAD`'s text, hashed whole, no longer matching: the line above alone
  read the same after a renumbering wherever it was blank or `}`. Only then, and
  never on a plain miss, is it the change under the same unchanged line holding
  its first line with a letter or digit, nearest its place: `}` or a blank line
  repeats across a file and sent the box hundreds of lines away. Where neither
  finds it the box is let go, a lost box costing one press and a wrong one
  moving the caret off screen. Rows differ between Unified and Split and a
  hidden tab lets its rows go, which is why it is held by line at all. A split
  holds it as Unified does, each side showing half a change. The model keeps it
  as it keeps the scroll, so a tab hidden and shown again or switched between
  layouts boxes the same change and steps on from it. A re-read leaves a caret
  already inside the box alone, the box lasting only while it is. A rebuilt view
  keeps the box over a find match outside it, the box being the newer: a find
  step there would have let it go. It is the file's text colour softened, not a
  theme key, every theme's text reading against both tints, and drawn across the
  visible width, so a sideways scroll redraws its rows.
- **The caret a file opens with counts as no selection**, so a step down from
  there lands on a change on the first row: a new or deleted file is one change
  from row 0, and counting from that caret left both arrows grey.
- **The pages are glyphs on the panel's header, which reaches the window's
  top**, as Orca draws them: the worktree's header ends at the panel's edge, its
  actions menu beside it, and the panel's header carries the glyph that shuts
  it, where the worktree's header carries it while the panel is shut.
- **Changes counts against `HEAD` under Modified, and under Branch against where
  the branch left its project's base branch**, committed or not, new files
  whole: once an agent commits, Modified empties while Branch still shows its
  work. The base is the merged badge's (merged-branch.md), and the count is
  `diff-index` against `git merge-base HEAD <base>`, the working tree included.
- **Modified or Branch is one choice for the Changes list and every file tab,
  kept with the settings**, its switch drawn in both, so a tab never counts from
  somewhere other than the list it was opened from. Files counts against `HEAD`
  whatever it says, being what All was.
- **Branch is read on every status read of the panel's worktree**, one that
  moved no count included: an edit back to the base's text leaves the count
  against `HEAD` as it was, and under Staged Only an edit on disk moves no
  status at all. Each read waits ten times what the last cost, a second at
  least, so a busy checkout's take at most a tenth of a core. A git event and a
  new diff algorithm each set off a status read, so a reset that leaves the
  status alone is read too; the base resolving or moving reads it as well, and a
  scan that finds nothing moved reads nothing. A worktree being written or in a
  missing project is not read, as its status is not. Only the panel's worktree
  is read, its result forgotten with the listing or on leaving Branch, so coming
  back draws none as current, and a new file's lines are the status read's where
  it counted them.
- **A Branch read that fails keeps the last**, an unborn `HEAD` being the one
  failure that is a verdict, no shared history; a tab whose merge base git
  cannot read keeps its last rows rather than counting from `HEAD` unseen.
- **One `diff-index --raw --numstat` pass, numstat saying which paths changed
  and the raw record only how**: against a commit, a file whose stat alone
  moved, a touched one, gets a raw record and no count.
- **No base branch, no Branch**: the list is empty and its footer says so once a
  scan has said so, saying nothing before, and a file tab offers no switch,
  counting from `HEAD`. A branch sharing no history with its base, or with no
  commit yet, says that instead, its tabs counting from `HEAD` under either.
  Cost: a project no scan has answered for, missing or failing, lists nothing
  under Branch and says nothing.
- **A tab under Branch marks nothing staged**, the index holding the branch's
  commits too: every change is drawn filled, and VoiceOver says neither staged
  nor unstaged. On the base itself, no commit of its own yet, the merge base is
  `HEAD` and the marks are exact, so they stay. Before its project's first scan
  a tab under Branch counts from `HEAD`, the scan reading it again, as waiting
  would leave it blank where a scan never answers; a hidden tab's dot follows a
  new scope's or base's reads until it is shown, a new diff algorithm or base
  tip leaving it as it was. A file the branch added and has since deleted shows
  `HEAD`'s text removed, the base holding none. A submodule's file still counts
  from the submodule's `HEAD`, its bar keeping the switch, which is the one
  choice and so still moves the list and the other tabs. Cost: a file the branch
  deleted lists under Branch but does not open, the open rule reading only the
  index's and `HEAD`'s copies.
- **Each read of a tab under Branch asks `git merge-base` afresh**, about 8 ms
  on Ghostty's 18,000 commits, rather than keeping one that a commit, a checkout
  or a fetch would each make stale. The tab's pace counts it.
- **Switching scope reads again the tabs in a project with a base**, at once
  rather than at their pace; a submodule's among them reads the same rows again,
  only a read telling which repository holds a file. A base that moves reads
  every tab in its project again under Branch, as it may move the merge base:
  fetching is the user's, so that is rare.
- **The worktree's header ends where the panel begins**, so at the narrowest it
  is clipped from its leading side sooner, its names going before the actions
  menu does.
- **A tab counts its anchors and saved scroll by the committed side**, the merge
  base's text under Branch, so a new scope moves them as a commit does.
- **A tab's dot under Branch is the panel's Branch read's** where the panel
  holds a current one, a submodule's file keeping its submodule's status. Cost:
  with the panel elsewhere it has none for what its rows cannot tell, a binary
  file or a hidden tab, the status counting from `HEAD`; recording the kind on
  the tab's own read would end that.
- **A click on a row's git badge sets Modified for every tab too**, the scope
  being one choice, so a Branch reader loses the choice there.
- **A file taken out of the index but left on disk counts both its entries** in
  the list, as the badge does, while its tab draws it as the new file it is: the
  row says `+2 −2` where the tab says `+2`.
- **Costs left under Branch**: a merge base git cannot read leaves a tab its
  last rows of text, which may be the other scope's after a switch, and one with
  none says git could not say, rather than count from `HEAD` unseen; a Branch
  read that fails with none before it leaves the list blank, its footer saying
  it could not read; and with a local `main` as the base, each commit to it
  reads every tab in the project again, as a fetch does a remote one, at once; a
  scope switch landing mid-read waits out that read's pace; each tab read asks
  `rev-parse HEAD` beside `merge-base`, run at once; a Branch tab's saved
  scroll, numbered by the merge base, lands by `HEAD`'s numbering if the first
  read after a relaunch comes before its project's scan; and a worktree whose
  status read keeps failing reads no Branch either, its new files coming from
  that read.
- **PR and CI are the panel's third and fourth pages**, kept in the same saved
  choice as Files and Changes; services.md has what they read and when. Changes
  is still `git` on the command line and `modified` in the state file.

## Reviewed and left as is

Raised by reviews and settled; a review need not raise these again.

- **A fence closed where CommonMark would not.** The Markdown grammar closes a
  fence on a closer indented four spaces, and on an unquoted line of `>` and a
  fence. The injection follows the grammar so the code's colours and Markdown's
  agree; rules of our own over its last line were tried and dropped.
- **A fence indented one to three spaces keeping that indent in its code.**
  CommonMark strips it; tried with Python, `def` and `return` still colour.
- **Quote markers re-coloured from the host's own spans.** Those spans are the
  markers' nodes exactly, and the filter runs only where a fence is quoted or in
  a list, a blank line's empty marker dropped. Leaving the markers out of the
  plain span and the injected spans would split both around every marker.
- **Every GitHub alias.** The common names are listed; rarer ones such as
  `shell-script` or `xhtml` are not.
- **A private helper in `HighlightInjections.swift`.** A private function stays
  in its type's file, as `body(of:)` does; a helper type gets its own.
- **`lineFeed` kept in `SyntaxHighlighter` rather than `ASCIIUnits`.**
  `ASCIIUnits` holds the units more than one scanner compares; this has one
  reader.
- **`"makefile"` in both `byCodeFenceName` and `byFileName`.** `byFileName`
  matches a file's name in its own case; a fence's name is folded, so reading it
  there would take `.bashrc` or `brewfile` as fence names by accident.
