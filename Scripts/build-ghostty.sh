#!/bin/bash
# Builds libghostty from ThirdParty/ghostty with its patches; dependencies.md.
# --zig-version and --fingerprint print what CI installs and caches on.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/Scripts/build-lib.sh"

ghostty="$root/ThirdParty/ghostty"
patches=("$root"/ThirdParty/ghostty-patches/*.patch)
output="$root/.build/ghostty"
# Zig's own place, which Ghostty's .gitignore covers: outside .build, so
# `make clean` and `swift package reset` leave the next build warm.
zig_cache="$ghostty/.zig-cache"
xcframework="$output/GhosttyKit.xcframework"
fingerprint_file="$output/fingerprint"
lock_file="$root/.build/ghostty.lock"
applied=()
zig=""

# Two builds at once, `make test` beside `make run`, would each revert the
# patches under the other and delete its output.
hold_lock() {
    mkdir -p "$root/.build"
    if [ -z "${MULTISHELL_GHOSTTY_LOCKED-}" ] && command -v lockf >/dev/null; then
        MULTISHELL_GHOSTTY_LOCKED=1 exec lockf -k "$lock_file" "$root/Scripts/build-ghostty.sh" "$@"
    fi
}

checked_out_commit() {
    if [ -e "$ghostty/.git" ]; then git -C "$ghostty" rev-parse HEAD; fi
}

is_applied() {
    git -C "$ghostty" apply --reverse --check "$1" 2>/dev/null
}

# A build killed mid-way leaves patches applied. Out before the checkout moves
# or the fingerprint is taken, or it differs from the clean tree's.
revert_leftover_patches() {
    [ -n "$(checked_out_commit)" ] || return 0
    git -C "$ghostty" diff --quiet && return 0
    local index
    for ((index = ${#patches[@]} - 1; index >= 0; index--)); do
        if is_applied "${patches[index]}"; then
            git -C "$ghostty" apply --reverse "${patches[index]}"
        fi
    done
}

# Moves an empty or stale submodule to the pin, never one past it: a bump in
# progress, or a checkout of a branch pinned earlier; dependencies.md.
check_out_pin() {
    local pinned current
    pinned="$(git -C "$root" ls-files -s ThirdParty/ghostty | cut -d' ' -f2)"
    current="$(checked_out_commit)"
    if [ -z "$current" ] || { [ "$current" != "$pinned" ] \
        && ! git -C "$ghostty" merge-base --is-ancestor "$pinned" HEAD 2>/dev/null; }; then
        git -C "$root" submodule update --init ThirdParty/ghostty >&2
        current="$(checked_out_commit)"
    fi
    [ "$pinned" = "$current" ] || die \
        "error: ThirdParty/ghostty is at ${current:0:9}, past the pin ${pinned:0:9}." \
        "       git submodule update ThirdParty/ghostty to go back to the pin, or, in a" \
        "       bump of your own, git add ThirdParty/ghostty to move the pin."
}

major_minor() {
    printf %s "$1" | cut -d. -f1-2
}

is_zig() {
    [ -x "$1" ] && [ "$(major_minor "$("$1" version)")" = "$2" ]
}

# Ghostty's build refuses any other major.minor, after a long dependency fetch.
# Homebrew's `zig` moves on before Ghostty does, and its `zig@X.Y` is off PATH.
required_zig_version() {
    sed -n 's/.*minimum_zig_version = "\(.*\)".*/\1/p' "$ghostty/build.zig.zon"
}

find_zig() {
    local required wanted keg
    required="$(required_zig_version)"
    wanted="$(major_minor "$required")"
    if [ -n "${ZIG-}" ]; then
        is_zig "$ZIG" "$wanted" || die "error: Ghostty needs Zig $required, and ZIG=$ZIG is not it."
        zig="$ZIG"
    elif is_zig "$(command -v zig || true)" "$wanted"; then
        zig="$(command -v zig)"
    elif keg="$(brew --prefix "zig@$wanted" 2>/dev/null)" && is_zig "$keg/bin/zig" "$wanted"; then
        zig="$keg/bin/zig"
    else
        die "error: Ghostty needs Zig $required, and none was found." \
            "       brew install zig@$wanted, or set ZIG to one. See Docs/develop/build.md."
    fi
}

fingerprint() {
    {
        git -C "$ghostty" rev-parse HEAD
        git -C "$ghostty" diff --no-ext-diff
        "$zig" version
        xcodebuild -version
        cat "${BASH_SOURCE[0]}" "${patches[@]}"
    } | shasum -a 256 | cut -d' ' -f1
}

is_built() {
    [ -d "$xcframework" ] && [ "$(cat "$fingerprint_file" 2>/dev/null)" = "$1" ]
}

# Runs on exit, however the build ends, so the submodule is left as it was.
revert_applied_patches() {
    local index
    for ((index = ${#applied[@]} - 1; index >= 0; index--)); do
        git -C "$ghostty" apply --reverse "${applied[index]}"
    done
}

apply_patches() {
    local pristine=0 patch
    git -C "$ghostty" diff --quiet && pristine=1
    for patch in "${patches[@]}"; do
        # In a clean tree it can only be the pin's own code; reverting it would
        # take upstream's change out and leave the submodule modified.
        if [ "$pristine" = 1 ] && is_applied "$patch"; then
            die "error: Ghostty at the pin already has $(basename "$patch"); delete it."
        fi
        if ! is_applied "$patch"; then
            git -C "$ghostty" apply "$patch" || die "error: $patch no longer applies to" \
                "       ThirdParty/ghostty; cut it again against the new pin (dependencies.md)."
        fi
        applied+=("$patch")
    done
}

# Native and macOS alone, COMPAT.md. What the app never uses is left out, and
# with it the libraries it links: libintl, glslang, imgui; dependencies.md.
build() {
    rm -rf "$output"
    mkdir -p "$output" "$zig_cache"
    (cd "$ghostty" && "$zig" build -Doptimize=ReleaseFast \
        -Demit-xcframework=true -Dxcframework-target=native -Demit-macos-app=false \
        -Dsentry=false -Demit-docs=false -Demit-themes=false -Di18n=false \
        -Dcustom-shaders=false -Dinspector=false \
        --prefix "$output" --cache-dir "$zig_cache")
    cp -R "$ghostty/macos/GhosttyKit.xcframework" "$xcframework"
}

hold_lock "$@"
revert_leftover_patches
check_out_pin
if [ "${1-}" = --zig-version ]; then
    required_zig_version
    exit 0
fi
find_zig
current="$(fingerprint)"
if [ "${1-}" = --fingerprint ]; then
    echo "$current"
    exit 0
fi
is_built "$current" && exit 0
trap revert_applied_patches EXIT
apply_patches
build
printf '%s\n' "$current" > "$fingerprint_file"
echo "built $xcframework"
