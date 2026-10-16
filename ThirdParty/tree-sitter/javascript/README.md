# tree-sitter-javascript

The scanner of https://github.com/tree-sitter/tree-sitter-javascript at the tag
`v0.25.0` (commit 44c892e0be055ac465d5eeddae6d3e194424e7de), which Package.swift
pins as a package. That package tests for its scanner against the working
directory, so as a dependency it builds without one and fails to link; the
`TreeSitterScanners` target compiles it here instead. Kept: `src/scanner.c`, the
headers beside it and the licence. Moving the pin is copying them from the same
tag; see Docs/develop/dependencies.md. Delete this folder once
https://github.com/tree-sitter/tree-sitter-javascript/pull/383 or its like is
merged and tagged.
