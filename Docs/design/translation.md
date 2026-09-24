# Translation

Where the words are, why they are not in the views, what stays in English.
Newest at the bottom.

- **Every word the app shows is a lookup by key.** The English sits against that
  key in a catalogue sorted by key, which groups it by the part of the app it is
  in and puts a new one in one place.
- **Cost: nothing checks the order**, and six of the libraries' entries had
  drifted out of it before a pass re-sorted them.
- **A prefix is a thing, singular, or a settings page, plural**: `action.` for a
  verb anywhere, `notification.` for a banner and `notifications.` for its page,
  `worktree.` for a fault of one and `worktrees.` for the page.
- **A language is that folder again under its code**, plus a line in the
  manifest. Nothing else changes.
- **The key is written at the call site**, not behind a name for it. An enum of
  keys cost the English twice, as a case name and as a value, to buy a compile
  error on a typo.
- **TranslationTests buys that instead**, one per catalogue, each reading the
  keys off its own half of the source and failing a missing key, an unused entry
  and a call passing the wrong number of arguments.
- **Cost: a mistyped key is a test failure, not a compile error**, and the scan
  only sees a key written as a literal. Nothing builds one at runtime, and
  nothing should.
- **Views hold no literal.** A bare string would be looked up in the main
  bundle, where there is no catalogue, and every check above starts at a lookup
  call so none of them would see it.
- **So a test scans for the initialisers and modifiers that take a localized
  key** and fails a literal in one, skipping a literal holding an interpolation,
  which is a number rather than a word.
- **One catalogue per frontend and one for the libraries**, each inside the
  target that declares it, the only place SwiftPM promises a resource may be.
- **A manifest reaching out of its target broke that**: the same relative path
  in two manifests meant two different folders, and neither was where it looked.
- **The split falls where the code does**, all but a handful of keys being asked
  for by one half. It is the line between what any frontend needs and what these
  windows need.
- **The reason is the port.** A Linux frontend shares the model's words and
  needs none of these widgets' labels, so fusing them would make it adopt this
  catalogue whole or fork the lot.
- **The lookup function is declared twice**, once per catalogue. A function in
  the module beats the same one imported, so a call site gets its own half
  without saying so. Only a module importing both has to qualify it.
- **App code never reads the libraries' catalogue.** The few words both halves
  say are written in both files, because the alternative makes a frontend's
  words depend on the model's.
- **Cost: those few can drift**, and a test fails a pair that has. It compares
  like with like, so a key that was a phrase here and a counted form there
  passed unseen until a second check failed that too.
- **Not `.xcstrings`.** SwiftPM copies one verbatim rather than compiling it, so
  every lookup answers with its own key. Checked against the toolchain, not
  assumed.
- **Resource lookup goes through one wrapper**, because the `swift build`
  accessor looks beside the executable and never where the bundling script puts
  the resource bundles. Both binaries in the bundle now come from xcodebuild,
  whose accessor does look there, so the wrapper only guards a `swift build`
  binary. It does nothing for the helper, whose main bundle is
  `Contents/Helpers`.
- **A new key when in doubt, not a shared one.** The same English word is held
  by several keys on purpose: a column, a state and a sort order need not be one
  word in every language.
- **Shared only where the word is the same act wherever it appears**: Cancel,
  Copy, Reveal in Finder, Clear Status. Close Tab is not one of them, the menu
  item and the dialog button having their own.
- **Counted things have a rule, not an `s`.** Putting an `s` on the noun is
  English's plural and no one else's, so each counted form is its own entry with
  the forms its language has.
- **Read where it is shown**, not through a helper: the rule is in the
  catalogue, so a wrapper round the lookup would only be a second name for it.
- **A phrase with two or more arguments numbers them**, so a translation may
  reorder the sentence. A test fails one that does not.
- **A noun read mid-sentence has both forms in the catalogue**, rather than one
  and a lowercasing, which is right in English and wrong in German.
- **What another program said stays English**: git's stderr, a hook's output, an
  exception's description. The app's words around them are translated.
- **The helper's own output stays English too.** Its words sit in a terminal
  beside git's and its commands are English tokens, so half a translated
  sentence reads worse than none.
- **It also must not start.** The helper's main bundle is `Contents/Helpers`,
  which holds no resource bundle, so a lookup there finds no catalogue and the
  accessor traps.
- **Proper names stay**: the engine, the agents, the built-in themes. The icon
  picker's group names are the only words in it.
- **The permission strings are in the Info.plist, not the catalogue.** A
  translation of them is an `InfoPlist.strings` beside the same language's
  catalogue, which the bundling script copies into the bundle's resources.
- **An error type's `description` is not a translation.** One reached through
  the default arm printed as written in every language, and the tests cannot see
  it, there being no lookup call site.
- **So the words live in `PresentedError`** and the error carries only its
  fields, keeping the process library free of a catalogue. A `description` stays
  on each as the form the log prints.
- **A new error type the user will see needs an arm there**, not a sentence in
  its `description`.
- **The system decides the language and there is no picker.** macOS has one per
  app already; ours would want a persisted field, a resolver and either a
  relaunch prompt or every string re-read live.
- **macOS reads the language list from the app's Info.plist**, not the resource
  bundle, so the bundling script writes it from the frontend's folders. The
  libraries' half has to keep pace and nothing checks that it has.
- **Only the reader's own words are folded by the reader's alphabet.** The
  sidebar filter folds by Unicode's rules with no locale, because the
  locale-aware match stops folding the dotted and dotless I under a Turkish
  locale, which follows the system rather than the bundle.
- **The icon picker's search is gone rather than translated**: a catalogue entry
  per symbol name to find a glyph in a palette small enough to read by eye, and
  every locale but English searching words it could not see.
- **Errors are mapped, not stringified.** The alert is the only place a user
  learns why something failed, so it gets git's own words.
- **A number in a phrase carries no locale, and that is a won't-fix.** A
  runtime's tenths read `0.4s` in a region that writes a comma.
  `String(format:)` given a locale also groups every integer, so the git badge
  grew a separator and no longer fit the row, and it picks the counted phrases'
  plural rules by it: English words under a Russian region read `21 subagent`.
  Formatting the one fraction apart fixed it but was more code than the comma is
  worth.
