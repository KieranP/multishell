# tree-sitter-python

The scanner of https://github.com/tree-sitter/tree-sitter-python at the tag
`v0.25.0` (commit 293fdc02038ee2bf0e2e206711b69c90ac0d413f), which Package.swift
pins as a package. That package tests for its scanner against the working
directory, so as a dependency it builds without one and fails to link; the
`TreeSitterScanners` target compiles it here instead. Kept: `src/scanner.c`, the
headers beside it and the licence. Moving the pin is copying them from the same
tag; see Docs/develop/dependencies.md. Delete this folder once upstream builds
its scanner from its manifest.
