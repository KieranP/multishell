# tree-sitter-css

The scanner of https://github.com/tree-sitter/tree-sitter-css at the tag
`v0.25.0` (commit dda5cfc5722c429eaba1c910ca32c2c0c5bb1a3f), which Package.swift
pins as a package. That package tests for its scanner against the working
directory, so as a dependency it builds without one and fails to link; the
`TreeSitterScanners` target compiles it here instead. Kept: `src/scanner.c`, the
headers beside it and the licence. Moving the pin is copying them from the same
tag; see Docs/develop/dependencies.md. Delete this folder once upstream builds
its scanner from its manifest.
