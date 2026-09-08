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
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
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

# Ad-hoc signing: unsigned bundles are killed on launch on Apple silicon.
codesign --force --sign - "$app/Contents/Helpers/multishell" >/dev/null 2>&1 || true
codesign --force --sign - "$app" >/dev/null 2>&1 || true

echo "built $app ($version)"
