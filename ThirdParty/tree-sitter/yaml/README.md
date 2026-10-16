# tree-sitter-yaml

The scanner of https://github.com/tree-sitter-grammars/tree-sitter-yaml at the
tag `v0.7.2` (commit 7708026449bed86239b1cd5bce6e3c34dbca6415), which
Package.swift pins as a package. That package tests for its scanner against the
working directory, so as a dependency it builds without one and fails to link;
the `TreeSitterScanners` target compiles it here instead. Kept: `src/scanner.c`,
`src/schema.core.c` it includes, the headers beside it and the licence. Moving
the pin is copying them from the same tag; see Docs/develop/dependencies.md.
Delete this folder once
https://github.com/tree-sitter-grammars/tree-sitter-yaml/pull/46 or its like is
merged and tagged.
