# Dependencies

The three worth knowing about.

## Dependencies worth knowing about

- libghostty via `Lakr233/libghostty-spm`, pinned to an exact tag, the
  embedding API not being stable. Third-party prebuilt with patches; build
  from source with its `Script/build.sh` before distributing.
- SwiftTerm, pure Swift, no binary.
- `WeightedSplit` uses `_VariadicView`, an underscored SwiftUI API.
