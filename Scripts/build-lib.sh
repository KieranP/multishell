#!/bin/bash
# The parts of a bundle build that are not about this bundle. Sourced by
# make-app.sh, which sets `set -euo pipefail`; nothing here runs on its own.

# The copyright the bundle carries. One place, so LICENSE, the About box and
# the notices cannot say three different things.
COPYRIGHT_HOLDER="Kieran Pilkington"
COPYRIGHT_YEARS="2026"

# Reports and stops. Each argument is a line, so a reason can carry its detail.
die() {
    printf '%s\n' "$@" >&2
    exit 1
}

# The version names the commit, so a bug report identifies what was installed.
# A tree with uncommitted work says so: its binary matches no commit.
bundle_version() {
    local root="$1" commit committed
    commit="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    committed="$(git -C "$root" log -1 --format=%cd --date=format:%Y.%m.%d 2>/dev/null || echo 0.0.0)"
    if [ -n "$(git -C "$root" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
        commit="$commit-dirty"
    fi
    printf %s "$committed-$commit"
}

# CFBundleVersion takes only digits and dots, hence the commit count here and
# the readable string in CFBundleShortVersionString.
bundle_build_number() {
    git -C "$1" rev-list --count HEAD 2>/dev/null || echo 0
}

# The worktree a debug bundle was built from, so two can `make run` over their
# own state. Spelled down because the name reaches the Info.plist; build.md.
bundle_variant() {
    local root="$1" config="$2"
    [ "$config" != "release" ] || return 0
    [ "$(git -C "$root" rev-parse --git-dir 2>/dev/null)" \
        != "$(git -C "$root" rev-parse --git-common-dir 2>/dev/null)" ] || return 0
    printf %s "$(basename "$root")" | tr -c 'A-Za-z0-9_-' '-'
}

# What the About box shows under the version, and the only place the holder
# is written. AGPL section 5 wants the notice on the work it covers, and the
# bundle carries LICENSE and THIRD-PARTY-NOTICES.md beside it.
bundle_copyright() {
    printf 'Copyright © %s %s. Licensed under the GNU AGPL v3.' \
        "$COPYRIGHT_YEARS" "$COPYRIGHT_HOLDER"
}

# xcodebuild rather than swift build, logged rather than -quiet, coverage and
# its own signing off: build.md, "Why the app is built through xcodebuild".
xcode_build() {
    local package="$1" scheme="$2" derived="$3" configuration="$4"
    local log="$derived/xcodebuild-$configuration.log"
    mkdir -p "$derived"
    if ! (cd "$package" && xcodebuild -scheme "$scheme" -configuration "$configuration" \
        -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath "$derived" \
        CODE_SIGNING_ALLOWED=NO CLANG_COVERAGE_MAPPING=NO build > "$log" 2>&1); then
        cat "$log" >&2
        exit 1
    fi
    # xcodebuild repeats a warning per compile step and again in its summary.
    grep -E ': (warning|error): ' "$log" | sort -u >&2 || true
}

# The three ways an xcodebuild product has come out wrong here, and why each
# check pipes into `grep -c` rather than `grep -q`: build.md.
verify_binary() {
    local binary="$1"
    if strings "$binary" | grep -c '\.build/.*\.bundle$' >/dev/null; then
        die "error: $binary looks for its resource bundles under a .build directory," \
            "       so the installed app would stop working at the next build there." \
            "       See Docs/develop/build.md."
    fi
    if otool -l "$binary" | grep -c __llvm_prf >/dev/null; then
        die "error: $binary is instrumented for code coverage, which slows it and" \
            "       writes profile files at exit; xcodebuild ignored CLANG_COVERAGE_MAPPING=NO."
    fi
    # The destination also matches Mac Catalyst, and xcodebuild takes the first.
    if ! otool -l "$binary" | grep -A2 LC_BUILD_VERSION | grep -c 'platform 1$' >/dev/null; then
        die "error: $binary was not built for macOS itself; xcodebuild took another" \
            "       variant of the destination. See Docs/develop/build.md."
    fi
}

# GhosttyTerminal ships terminfo and config as SPM resource bundles; without
# them libghostty starts with no terminfo and every child process misbehaves.
copy_resource_bundles() {
    local products="$1" destination="$2" bundle count=0
    for bundle in "$products"/*.bundle; do
        [ -e "$bundle" ] || continue
        cp -R "$bundle" "$destination/"
        count=$((count + 1))
    done
    # Counted, because a glob matching nothing is no error to `set -e`: the
    # build used to finish quietly on an app whose terminals all misbehave.
    if [ "$count" -eq 0 ]; then
        die "error: no resource bundles in $products; libghostty would start with no" \
            "       terminfo. Build the package first."
    fi
}

# InfoPlist.strings alone, the one macOS reads through Bundle.main: the app's
# own words travel in the target's resource bundle; translation.md.
copy_info_plist_strings() {
    local resources="$1" destination="$2" lproj
    for lproj in "$resources"/*.lproj; do
        [ -f "$lproj/InfoPlist.strings" ] || continue
        mkdir -p "$destination/$(basename "$lproj")"
        cp "$lproj/InfoPlist.strings" "$destination/$(basename "$lproj")/"
    done
}

# Prints the template with each remaining argument pair replaced, placeholder
# then value. Bash's own replacement, so no value needs escaping; build.md.
render_template() {
    local template="$1" text
    shift
    text="$(cat "$template")"
    while [ "$#" -gt 1 ]; do
        text="${text//$1/$2}"
        shift 2
    done
    # A dropped pair at the call site would otherwise ship a plist whose
    # version or variant is the placeholder, which parses and means nothing.
    if printf %s "$text" | grep -c '@[A-Z_][A-Z_]*@' >/dev/null; then
        die "error: $template still holds $(printf %s "$text" |
            grep -o '@[A-Z_][A-Z_]*@' | sort -u | tr '\n' ' ')after substitution."
    fi
    printf '%s\n' "$text"
}

# The languages the app has, as CFBundleLocalizations rows, from the app
# half's folders alone; build.md.
bundle_localizations() {
    local resources="$1" lproj
    for lproj in "$resources"/*.lproj; do
        [ -d "$lproj" ] || continue
        printf '        <string>%s</string>\n' "$(basename "$lproj" .lproj)"
    done
}

# Which identity signs decides whether the app keeps its privacy grants;
# make-signing-identity.sh. Ad hoc is the fallback, so a fresh clone builds.
signing_identity() {
    local identity="${MULTISHELL_SIGN_IDENTITY:-Multishell Dev}"
    if [ "$identity" != "-" ] && ! security find-certificate -c "$identity" >/dev/null 2>&1; then
        echo "note: no '$identity' certificate; signing ad hoc, so macOS will ask" >&2
        echo "      for file permissions again after this install. Create one:" >&2
        echo "      make signing-identity" >&2
        identity="-"
    fi
    printf %s "$identity"
}

# An unsigned bundle is killed on launch on Apple silicon, so this is not
# optional and a failure is a warning rather than a stop.
sign() {
    local identity="$1" path="$2" output
    if output="$(codesign --force --sign "$identity" "$path" 2>&1)"; then
        return
    fi
    if [ "$identity" = "-" ]; then
        echo "warning: ad-hoc signing $path failed, and macOS kills an unsigned" >&2
        echo "         bundle on launch: $output" >&2
        return
    fi
    # Worth the noise: a silent fall back to ad hoc is what the certificate
    # exists to avoid, and the reason is the only way to fix it.
    echo "warning: signing $path as '$identity' failed; signing ad hoc" >&2
    echo "         $output" >&2
    codesign --force --sign - "$path" >/dev/null 2>&1 || true
}
