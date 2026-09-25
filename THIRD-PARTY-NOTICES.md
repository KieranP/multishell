# Third party notices

Multishell is licensed under the GNU Affero General Public License v3.0; see
[LICENSE](LICENSE). The executable also contains the software below, most of it
inside the prebuilt `libghostty` library, built from Ghostty at commit
`3c47ca1`. Each licence text is in [Licenses/](Licenses/), which ships in the
app bundle beside this file.

| Component                 | Copyright                                            | Licence                     | Text                                                                                 |
| ------------------------- | ---------------------------------------------------- | --------------------------- | ------------------------------------------------------------------------------------ |
| libghostty-spm            | 2026 @Lakr233                                        | MIT                         | [libghostty-spm.txt](Licenses/libghostty-spm.txt)                                    |
| MSDisplayLink             | 2024 Lakr Aream                                      | MIT                         | [MSDisplayLink.txt](Licenses/MSDisplayLink.txt)                                      |
| Ghostty                   | 2024 Mitchell Hashimoto, Ghostty contributors        | MIT                         | [Ghostty.txt](Licenses/Ghostty.txt)                                                  |
| Zig standard library      | Zig contributors                                     | MIT                         | [Zig.txt](Licenses/Zig.txt)                                                          |
| libxev                    | 2023 Mitchell Hashimoto                              | MIT                         | [libxev.txt](Licenses/libxev.txt)                                                    |
| libvaxis                  | 2023 Tim Culverhouse                                 | MIT                         | [libvaxis.txt](Licenses/libvaxis.txt)                                                |
| zig-objc                  | 2023 Mitchell Hashimoto                              | MIT                         | [zig-objc.txt](Licenses/zig-objc.txt)                                                |
| z2d                       | 2024-2026 Chris Marchesi                             | MPL-2.0, with MIT portions  | [z2d.txt](Licenses/z2d.txt), [MPL-2.0.txt](Licenses/MPL-2.0.txt)                     |
| uucode                    | 2026 Jacob Sandlund                                  | MIT                         | [uucode.txt](Licenses/uucode.txt)                                                    |
| Unicode data, via uucode  | 1991-2025 Unicode, Inc.                              | Unicode License v3          | [Unicode.txt](Licenses/Unicode.txt)                                                  |
| Oniguruma                 | 2002-2021 K.Kosako                                   | BSD-2-Clause                | [Oniguruma.txt](Licenses/Oniguruma.txt)                                              |
| simdutf                   | 2021 The simdutf authors                             | MIT                         | [simdutf.txt](Licenses/simdutf.txt)                                                  |
| Highway                   | The Highway Project Authors                          | BSD-3-Clause                | [Highway.txt](Licenses/Highway.txt)                                                  |
| Wuffs                     | 2023 The Wuffs Authors                               | MIT                         | [Wuffs.txt](Licenses/Wuffs.txt)                                                      |
| GNU libintl, gettext 0.24 | 1995-2025 Free Software Foundation, Inc.             | LGPL-2.1-or-later           | [LGPL-2.1.txt](Licenses/LGPL-2.1.txt)                                                |
| JetBrains Mono            | 2020 The JetBrains Mono Project Authors              | OFL-1.1                     | [JetBrains-Mono.txt](Licenses/JetBrains-Mono.txt)                                    |
| Symbols Nerd Font 3.4.0   | 2014 Ryan L McIntyre                                 | MIT, glyphs under their own | [Nerd-Fonts.txt](Licenses/Nerd-Fonts.txt), [Apache-2.0.txt](Licenses/Apache-2.0.txt) |
| swift-subprocess          | 2025 Apple Inc. and the Swift project authors        | Apache-2.0                  | [Apache-2.0.txt](Licenses/Apache-2.0.txt)                                            |
| swift-system              | 2020 Apple Inc. and the Swift System project authors | Apache-2.0                  | [Apache-2.0.txt](Licenses/Apache-2.0.txt)                                            |

simdutf, Highway and Wuffs are each also offered under Apache-2.0; Multishell
takes the licence named above.

The z2d source shipped is
<https://github.com/vancluever/z2d/tree/7dbae85c81784dba9988320bf9543ed9a81350c8>.

libintl is linked statically. To relink the app against a modified copy, use the
gettext 0.24 source (<https://ftp.gnu.org/gnu/gettext/gettext-0.24.tar.gz>),
Ghostty's source at the commit above, libghostty-spm's build scripts, and this
repository.

The Nerd Font's glyphs come from icon sets under their own licences, listed in
<https://github.com/ryanoasis/nerd-fonts/blob/v3.4.0/license-audit.md>. Font
Awesome (Fonticons, Inc.) and Codicons (Microsoft) are CC BY 4.0, and Material
Design Icons is Apache-2.0.

bash-preexec (MIT, 2017 Ryan Caloras and contributors) ships as a file in
libghostty-spm's resource bundle, with its licence beside it as
`GhosttyKit_GhosttyTerminal.bundle/Contents/Resources/Ghostty/shell-integration/bash/LICENSE-bash-preexec.md`.

## Agent marks

The marks in `Sources/MultishellAppUI/Resources/Marks/` are traced from Claude
Code's, Codex's, Gemini CLI's, GitHub Copilot's and OpenCode's own. Each is its
vendor's trademark and identifies the agent in a pane; none implies endorsement,
and this project grants no rights over them.
