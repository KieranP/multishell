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
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>Multishell</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signing: unsigned bundles are killed on launch on Apple silicon.
codesign --force --sign - "$app/Contents/Helpers/multishell" >/dev/null 2>&1 || true
codesign --force --sign - "$app" >/dev/null 2>&1 || true

echo "built $app"
