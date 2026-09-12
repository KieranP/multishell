# Translation

Where the words are, why they are not in the views, and what is left in
English on purpose.
Newest at the bottom.

## Every word the app shows is `t("a.key")`

The English is against that key in a `Localizable.strings`, sorted by key,
which groups it by the part of the app the words are in and puts a new one
in one place. A language is that folder again under its code, plus a line
in the manifest; nothing else changes. Arguments fill a `%@` or a `%d` in:
`t("merged.into", base)`.

The key is written at the call site, not behind a name for it. An enum of
keys was the other way, and it cost the English twice over, once as a case
name and once as a value, to buy a compile error on a typo. What buys that
now is TranslationTests, one per catalogue, each reading the keys off its
own half of the source and failing one its catalogue has not got, an entry
nothing asks for, and a call passing the wrong number of arguments. Cost:
a mistyped key is a test failure and not a compile error, and the scan only
sees a key written as a literal, so one built at runtime would slip past
both directions of the check. Nothing builds one, and nothing should.

Views hold no literal. `Text(t("sidebar.projects"))`, and never
`Text("Projects")`, which would look the word up in `Bundle.main`, where
there is no catalogue.

## One catalogue per frontend, and one for the libraries

Two, and a third the day there is a second frontend:

    Sources/MultishellCore/Resources/en.lproj/         the libraries', 251 keys
    Apps/macOS/Sources/Multishell/Resources/en.lproj/  the Mac app's,   264 keys

Each folder is a `Localizable.strings` and a `Localizable.stringsdict`, and
those counts are both files: 243 + 8 counted forms, and 262 + 2.

Each inside the target that declares it, which is the only place SwiftPM
promises a resource may be. A manifest can reach out of its target and both
did for a while, but then `../../Resources` in the app's manifest and the
same string in the root's meant two different folders, and neither was
where it looked.

The split falls almost exactly where the code does. Of 510 keys, 259 are
asked for only by `Apps/macOS/Sources` and 246 only by `Sources`; five are
wanted by both. So it is not an arbitrary line through a translator's
file, it is the line between what any frontend needs and what these
windows need.

The reason is the port. A Linux frontend shares every word in the model and
the dialogs and needs none of the labels for widgets it will not have, so
fusing them would make it adopt this catalogue whole or fork the lot. Split,
it puts a `Resources` inside its own target and uses whatever its toolkit
translates with, while `Sources` goes on saying what a worktree status is
in both.

`t(_:_:)` is declared twice: `public` in MultishellCore, reading the
libraries' catalogue, and again in the Mac app target, reading the app's. A
function in the module beats the same one imported, so a view calling
`t("menu.new-tab")` gets the app's without saying so, and `SessionState`
calling `t("state.done")` gets the libraries'. Nothing at a call site says
which, and nothing needs to. Only a module importing both sees two: the app
test target does, and says `Multishell.t` or `MultishellCore.t`.

App code never reads the libraries' catalogue. The five words both halves
say are written in both files. Duplicated on purpose: the alternative is
`MultishellCore.t(…)` in a view, which makes a frontend's words depend on
the model's and is exactly what the split is for. Cost is five strings
translated twice, and that they can drift.

Not `.xcstrings`: SwiftPM copies it verbatim rather than compiling it, so
every lookup answers with its own key. Checked against the toolchain, not
assumed. `.strings` and `.stringsdict` it is, which `genstrings` and every
translation tool already read.

`Bundle.module` looks beside the executable and in the build directory,
never `Contents/Resources` where `make-app.sh` puts the resource bundles,
so both lookups go through `PackageBundle`, which tries there first and
takes the bundle's name as an argument because there are now two. Same
workaround the shell-integration scripts already needed.

## A new key when in doubt, not a shared one

Twelve English strings are held by more than one key, twenty-five keys in
all: `lane.done` and `state.done` are both "Done", `sidebar.name-prompt` and
`sort.alphabetical` are both "Name", the Terminal menu and the Terminal
settings page are both "Terminal". Deliberate. A shared key cannot be told
apart by a translator, and the column, the state and the sort order need not
be one word in every language; the cost of splitting is that someone types
the same translation twice, and the cost of sharing is a translation that
cannot be right.

Shared anyway where the word is the same act wherever it appears: Cancel,
Copy, Reveal in Finder, Clear Status. Those are one key across every menu and
dialog that offers them. Close Tab is not one of them, and is in the twelve
above: the Cmd+W item and the close dialog's button share `close.tab-button`,
where the tab's own menu and its accessibility label are `tab.close`.

## Counted things have a rule, not an `s`

A count used to take the noun and put an `s` on it, which is English's
plural and no one else's. Each counted form is now its own key in
`Localizable.stringsdict` with `one` and `other`; a language with six forms
adds six. `t("count.worktrees", 3)`, read where it is shown rather than
through a helper: the rule is in the catalogue, so a wrapper round the
lookup would only be a second name for it.

A phrase taking two or more arguments numbers them, `%1$@ %2$@`, so a
translation may reorder the sentence. TranslationTests fails one that does
not.

A screen reader's line reads a noun mid-sentence, and lowercasing the
capitalised form is right in English and wrong in German, so
`AccessibilityText.kind(of:inSentence:)` and `AgentBoardLane.title(inSentence:)`
each have both forms in the catalogue rather than one and a `.lowercased()`.

## What stays in English

What another program said: git's stderr, a hook's output, an exception's
description. The app's own words around them are translated; the quoted text
is the tool's, and translating it would mean translating git.

The helper's own output: its usage, and what it says about a command it
does not know. Its words sit in a terminal beside git's, and its commands
are English tokens, so half a sentence translated around `command-finished`
reads worse than none. It also must not start: the helper is its own
`Bundle.main`, so `t(_:_:)` there would fall through to `Bundle.module`,
which is an absolute path into this build directory and traps everywhere
else. Nothing in `MultishellCLI` reaches the catalogue today.

Proper names: the engines, the agents, the built-in themes. The icon picker
has no search to translate; its group names are the only words in it.

The permission strings macOS shows, which are in the Info.plist rather than
the catalogue. A translation of them is an `InfoPlist.strings` beside the
`Localizable.strings` of the same language, under
`Apps/macOS/Sources/Multishell/Resources`; `make-app.sh` copies those, and
only those, into `Contents/Resources`, which is where `Bundle.main` looks
for them.

## The system decides the language, and there is no picker

macOS already has one, per app, in System Settings > General > Language &
Region. A preference of our own would want a persisted field, a resolver,
and either a relaunch prompt or every string re-read live, which SwiftUI
will not do for free.

It reads `CFBundleLocalizations` for that list, and looks for it in the app's
Info.plist, not in the resource bundle the catalogue travels in. So
`make-app.sh` writes the list from the `.lproj` folders of the frontend
being built: adding a language there adds it to the menu with no second
edit. The libraries' half has to keep pace, and nothing checks that it
has — a language listed with no `Sources` half draws its windows
translated and says what the model says in English.

## Only the reader's own words are folded by the reader's alphabet

`foldedContains` matches case and accents by Unicode's rules with no locale,
and it is what searches data that is not the reader's language: branch and
directory names in the sidebar filter. `localizedStandardContains` reads
`Locale.current`, and under `tr_TR` the dotted and dotless I stop folding
together, so an uppercase `I` typed into the filter stopped matching a branch
holding a lowercase one. Shipping English only is no protection:
`Locale.current` follows the system, not the bundle.

The icon picker had a search over English words for symbols named after the
picture, and it is gone rather than translated: 107 more catalogue entries to
find a glyph in a palette small enough to read by eye, and every locale but
English searching words it could not see.
