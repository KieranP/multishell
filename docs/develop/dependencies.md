# Dependencies

The three worth knowing about.

## Dependencies worth knowing about

- libghostty via `Lakr233/libghostty-spm`, pinned to an exact tag, the
  embedding API not being stable. Third-party prebuilt with patches; build
  from source with its `Script/build.sh` before distributing.
  - Moving the pin changes which config keys a user's Ghostty file may use,
    so `GhosttyUserConfig` wants a look then. What was run to write it:
    `ghostty +show-config --default` for the key list, each line handed to
    the pinned build alone, which took 206 of 207. `--docs` on the same
    command says what a key does, and is what the allowed list was decided
    from.
- SwiftTerm, pure Swift, no binary.
- `WeightedSplit` uses `_VariadicView`, an underscored SwiftUI API.
