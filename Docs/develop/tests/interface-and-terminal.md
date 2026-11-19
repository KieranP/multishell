# Interface and terminal

Which test catches which breach of the rules for shortcuts, alerts, views, the
sidebar, the settings window, translation, the terminal engine, drops and
highlighting. Why each rule holds is in `design/`.

## What catches a breach of the rules

- **No two commands default to one key, and none to a reserved one**:
  ShortcutCommandTests. **Every key the recorder takes is one libghostty
  parses**: KeyCombinationGhosttyTests. **The clipboard ones stay with the
  terminal**: GhosttyUnbindsTests.
- **Identifiers spelled in both Swift and the generated Info.plist still
  match**: InfoPlistTemplateTests. Nothing at build or run time notices these
  having parted.
- **The quit alert answers both keys under any language**: QuitAlertTests, with
  translated titles, since AppKit binds Escape by matching the English one.
- **A removal button keeps its red bezel and its Return**:
  DestructiveAlertTests. AppKit takes the key off at every layout and draws a
  default button in the accent colour. What a presented sheet draws is not
  testable here, so the suite holds the properties, bar macOS 27's alert button,
  which keeps no bezel colour: there the offscreen drawing is read.
- **Each override binds to its own setting**: AppModelSettingsBindingsTests, the
  override accessors all taking the same arguments and returning the same type.
- **A settings page outgrowing its fixed window**: ViewSettingsWindowTests. The
  bound is absolute, not a margin: the tallest, Project Hooks' Create part under
  a repository file asking for trust, measured 539 of 558 on 2026-11-06, so a
  macOS that grows its controls fails this first, rightly. Appearance stays in:
  its font list is the machine's, but a picker is one row however long.
- **One part is exempt**: Agents' Agent hooks part reads the machine on appear,
  so its height is the developer's. Width is not checkable at all, a
  minimum-size measurement reporting where text wraps.
- **A tab strip that stops answering the wheel**: SidewaysWheelViewTests and
  ViewSidewaysWheelTests. The same event handed straight to the scroller moves
  it by nothing, which is why the catcher exists. The run loop is spun by hand,
  since `run(until:)` returns at once while it has no source. With the screen
  locked the scroller never moved and the four turns that expect it failed,
  where the run before passed them on the same AppUI code (2026-10-23).
- **A word on screen with no translation, or a translation nothing shows**:
  TranslationTests, one per catalogue (design/translation.md). The two files are
  a pair sharing TestScratch's TranslationCallSites, so a check added to one
  goes in the other. The app's also pins the shadowing the split rests on.
- **Their odder checks have reasons**: the C-string specifier crashes rather
  than shows a wrong word; a counted form whose format key does not name its own
  sub-dictionary answers with the raw format; parsing hides an entry written
  twice or left blank; a scan that lost the source tree would pass but for a
  floor on call sites; and a skip-build run would pass on the stale built
  catalogue but for a byte comparison with the source one.
- **The sidebar filter is not folded by the reader's alphabet**:
  SidebarListingTests reads the source, the current locale being process-wide
  and so not movable for one suite.
- **Open in Editor and New Worktree over the board**: AppModelEditorTests and
  AppModel+NewWorktreeSheetTests+Request. **A rename undone by the commit after
  it**: AppModelTabRenamingTests.
- **A frame handed another session's surface asks that session for focus**:
  SurfaceFrameTests.
- **A promised drop's reader is called off the main actor**, as AppKit calls it:
  PromisedDropCollectorTests. A reader written as if on main died at the first
  file of every promised drop, which only a real drag shows. The drag itself
  cannot be staged, a promise being fulfilled through a drag session this
  process never gets.
- **An item promising two files is not delivered on the first**:
  PromisedDropCollectorTests. **Its files paste in the order it names them**:
  PromisedDropTests.
- **A real surface is made only where its lifetime or libghostty's own callback
  is the question**, on `/bin/sleep` and in no window on screen:
  GhosttySurfaceViewTests, GhosttySurfaceView+ProgramLinkTests, +ClipboardTests
  and +MemoryTests, GhosttyTerminalHostTests and GhosttyPaneEventMonitorTests. A
  failed expectation on a pane is read into a Bool first, as describing one
  trips over AppKit's cursors, null pointers in a test process. Everything else
  libghostty is handed is tested as values, in the Ghostty suites named for each
  part and PanePasteboardTests. Focus kept in step with the window is not
  tested: libghostty's own idea of it shows only on a live surface.
- **Under `make test` a surface's command never runs**: libghostty starts it
  through `/usr/bin/login`, setuid, which the sandbox refuses with `EPERM`. So a
  link clicked in a pane is tested from the event on (GhosttySurfaceEventTests,
  the GhosttyLink suites, GhosttyTerminalHostTests); that libghostty sends the
  event for a Cmd+click was seen by hand at Ghostty `ad97d33`.
- **The Ghostty config**: GhosttyLoadedConfigTests against the real libghostty,
  GhosttyUserConfigTests for a CRLF file, a file name Ghostty reads and we do
  not, and an include left unfollowed.
- **A find bar outliving its pane**: AppModelFindTests. **The steps' engine
  spellings**: GhosttySearchActionsTests.
- **The sidebar filter's field and keyboard**: AppModelSidebarFilterTests. **A
  project collapsed under it**: AppModelProjectExpansionTests,
  AppModel+StatusReadsTests+VisibleRows, and SidebarViewTests by pixels.
- **A header badge ringed in the sidebar's colour**: WorktreeHeaderTests.
- **A row TextKit 2 lays out away from where its number says**:
  DiffDocumentViewTests and SplitDiffDocumentViewTests, the only check on an
  override Apple does not document (design/files/file-tabs.md). **A file tab
  painting outside its frame**: DiffDocumentViewTests+Clipping.
- **A grammar bump whose query no longer compiles, or whose bundle is not
  found**: HighlightGrammarsTests.
- **Embedded languages left plain or coloured wrong**, a `<script>`, `<style>`,
  Svelte expression or Markdown fence: HighlightInjectionsTests and its suites,
  ElementBodyLanguageTests, SvelteBlockHeadTests, FencedCodeBlockTests,
  HTMLBlocksTests and HeadingTagBlocksTests. **A `>` or bare `&` in Svelte text
  leaving the rest of the file uncoloured**: SvelteGrammarInputTests and
  SyntaxHighlighterTests.
- **A drag nothing takes or a drop refuses goes back between the neighbours it
  left, and one a drop took stays**: AppModelTabDragTests.
- **A segmented picker drawn only as wide as its labels**:
  ViewSegmentedAcrossRowTests.
