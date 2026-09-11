#!/bin/bash
# Wraps the SPM executable into Multishell.app.
#
# SwiftPM cannot emit an app bundle, and macOS needs one for a Dock icon,
# activation, and the menu bar. Xcode replaces this once signing matters.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="${1:-debug}"
package="$root/Apps/macOS"
build="$package/.build/$config"
app="$root/build/Multishell.app"

# The version names the commit, so a bug report identifies what was installed.
# CFBundleVersion takes only digits and dots, hence the commit count there and
# the readable string in CFBundleShortVersionString. A tree with uncommitted
# work says so: its binary matches no commit.
commit="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown)"
commits="$(git -C "$root" rev-list --count HEAD 2>/dev/null || echo 0)"
committed="$(git -C "$root" log -1 --format=%cd --date=format:%Y.%m.%d 2>/dev/null || echo 0.0.0)"
if [ -n "$(git -C "$root" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    commit="$commit-dirty"
fi
version="$committed-$commit"

# A debug bundle built from a git worktree names that worktree, and Paths
# gives it its own state file, socket, integration directory and drops: two
# worktrees can then both `make run` without the last autosave winning. Empty
# from the checkout, which keeps the plain `.debug` files, and empty for
# release, which reads no key at all.
#
# Spelled down to a safe set here and not left to Paths, because the name goes
# into the XML below: an unescaped `&` in a branch name makes the whole
# Info.plist unparseable, and a bundle whose Info.plist will not parse does
# not launch.
worktree=""
if [ "$(git -C "$root" rev-parse --git-dir 2>/dev/null)" \
    != "$(git -C "$root" rev-parse --git-common-dir 2>/dev/null)" ]; then
    worktree="$(printf %s "$(basename "$root")" | tr -c 'A-Za-z0-9_-' '-')"
fi
variant=""
if [ "$config" != "release" ]; then
    variant="$worktree"
fi

swift build --package-path "$package" -c "$config"
# The helper is a product of the root package, which the app depends on but
# cannot list as a dependency (an executable product is not linkable).
swift build --package-path "$root" -c "$config" --product multishell

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Helpers"
cp "$build/Multishell" "$app/Contents/MacOS/Multishell"
cp "$root/.build/$config/multishell" "$app/Contents/Helpers/multishell"

# GhosttyTerminal ships terminfo and config as SPM resource bundles; without
# them libghostty starts with no terminfo and every child process misbehaves.
for bundle in "$build"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$app/Contents/Resources/"
done

cp "$package/Resources/Multishell.icns" "$app/Contents/Resources/Multishell.icns"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Multishell</string>
    <key>CFBundleDisplayName</key><string>Multishell</string>
    <key>CFBundleIdentifier</key><string>io.multishell.app</string>
    <key>CFBundleExecutable</key><string>Multishell</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>CFBundleVersion</key><string>$commits</string>
    <key>CFBundleIconFile</key><string>Multishell</string>
    <key>MultishellVariant</key><string>$variant</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <!-- What macOS puts under its own line in the permission alert. A
         terminal reaches these places because a command run in one did, and
         the alert names this app rather than that command: macOS holds the
         app that spawned a process responsible for what the process reads.
         Without a string here the alert offers the user no reason at all. -->
    <key>NSNetworkVolumesUsageDescription</key>
    <string>A command you ran in a Multishell terminal is reading files on a network volume.</string>
    <key>NSRemovableVolumesUsageDescription</key>
    <string>A command you ran in a Multishell terminal is reading files on a removable volume.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>A command you ran in a Multishell terminal is reading files on your Desktop.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>A command you ran in a Multishell terminal is reading files in your Documents folder.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>A command you ran in a Multishell terminal is reading files in your Downloads folder.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>A command you ran in a Multishell terminal is reading your photo library.</string>
    <key>NSAppleMusicUsageDescription</key>
    <string>A command you ran in a Multishell terminal is reading your media library.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Multishell asks the system to install its command line tool, which needs an administrator.</string>
    <!-- The pasteboard type a dragged tab carries. Declared so macOS knows
         it is ours; see TabTransfer. -->
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key><string>io.multishell.tab</string>
            <key>UTTypeDescription</key><string>Multishell Terminal Tab</string>
            <key>UTTypeConformsTo</key><array><string>public.data</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Signing. An unsigned bundle is killed on launch on Apple silicon, so this is
# not optional, but which identity signs decides whether the app keeps the
# privacy permissions the user granted it. TCC keys a grant to the signature's
# designated requirement, and an ad-hoc signature's requirement is a bare
# cdhash: it changes with every build, so each install asks again for the
# volumes and folders a terminal reaches, and the App Management box the user
# ticked stops matching and silently denies. A certificate makes the
# requirement name the certificate, which outlives a rebuild.
# Scripts/make-signing-identity.sh creates it; ad-hoc is the fallback so a
# fresh clone still builds.
identity="${MULTISHELL_SIGN_IDENTITY:-Multishell Dev}"
if [ "$identity" != "-" ] && ! security find-certificate -c "$identity" >/dev/null 2>&1; then
    echo "note: no '$identity' certificate; signing ad hoc, so macOS will ask" >&2
    echo "      for file permissions again after this install. Create one:" >&2
    echo "      make signing-identity" >&2
    identity="-"
fi

sign() {
    if output="$(codesign --force --sign "$identity" "$1" 2>&1)"; then
        return
    fi
    if [ "$identity" = "-" ]; then
        echo "warning: ad-hoc signing $1 failed, and macOS kills an unsigned" >&2
        echo "         bundle on launch: $output" >&2
        return
    fi
    # Worth the noise: a silent fall back to ad hoc is what the certificate
    # exists to avoid, and the reason is the only way to fix it.
    echo "warning: signing $1 as '$identity' failed; signing ad hoc" >&2
    echo "         $output" >&2
    codesign --force --sign - "$1" >/dev/null 2>&1 || true
}

sign "$app/Contents/Helpers/multishell"
sign "$app"
codesign --verify "$app" || echo "warning: $app is not validly signed" >&2

# SwiftPM writes this tree's own .build path into the binary as the only place
# Bundle.module looks that exists (the other is the app root, where codesign
# refuses to let the bundles live). From a worktree that path is the worktree,
# which is the one directory the user is expected to throw away.
if [ -n "$worktree" ]; then
    echo "note: built from a git worktree, so the bundle reads its resources from" >&2
    echo "      $root/Apps/macOS/.build" >&2
    echo "      and stops working once that worktree is removed. Build from the" >&2
    echo "      main checkout before 'make install'." >&2
fi

echo "built $app ($version)"
