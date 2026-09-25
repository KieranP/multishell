#!/bin/bash
# Wraps the SPM executable into Multishell.app, the bundle macOS needs and
# SwiftPM cannot emit; build.md.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/Scripts/build-lib.sh"

config="${1:-debug}"
case "$config" in
    debug) configuration=Debug ;;
    release) configuration=Release ;;
    *) die "error: config is debug or release, not '$config'" ;;
esac

app="$root/build/Multishell.app"
resources="$root/Sources/MultishellAppUI/Resources"
bundling="$root/Resources"
# One derived directory for both schemes, so the libraries compile once.
derived="$root/.build/xcode"
products="$derived/Build/Products/$configuration"

version="$(bundle_version "$root")"
commit="$(bundle_commit "$root")"
commits="$(bundle_build_number "$root")"
variant="$(bundle_variant "$root" "$config")"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Helpers"

# Build, verify, and copy the App
xcode_build "$root" Multishell "$derived" "$configuration"
verify_binary "$products/Multishell"
cp "$products/Multishell" "$app/Contents/MacOS/Multishell"

# Build, verify, and copy the CLI, installed under the name hooks call
xcode_build "$root" multishell-helper "$derived" "$configuration"
verify_binary "$products/multishell-helper"
cp "$products/multishell-helper" "$app/Contents/Helpers/multishell"

copy_resource_bundles "$products" "$app/Contents/Resources"
cp "$bundling/Multishell.icns" "$app/Contents/Resources/Multishell.icns"
# Each compiled-in dependency's licence must travel with the binary;
# THIRD-PARTY-NOTICES.md says which text in Licenses/ covers what.
cp "$root/LICENSE" "$app/Contents/Resources/LICENSE"
cp "$root/THIRD-PARTY-NOTICES.md" "$app/Contents/Resources/THIRD-PARTY-NOTICES.md"
cp -R "$root/Licenses" "$app/Contents/Resources/Licenses"
copy_info_plist_strings "$resources" "$app/Contents/Resources"

render_template "$bundling/Info.plist.in" \
    @VERSION@ "$version" \
    @BUILD@ "$commits" \
    @COMMIT@ "$commit" \
    @VARIANT@ "$variant" \
    @COPYRIGHT@ "$(bundle_copyright)" \
    @LOCALIZATIONS@ "$(bundle_localizations "$resources")" \
    > "$app/Contents/Info.plist"

identity="$(signing_identity)"
entitlements="$(bundle_entitlements \
    "$bundling/Multishell.entitlements" "$derived" "$config")"
# The helper needs none of the app's entitlements; in a debug build it takes
# the same file anyway, for the `get-task-allow` the debugger wants.
helper_entitlements=""
[ "$config" = "release" ] || helper_entitlements="$entitlements"
sign "$identity" "$app/Contents/Helpers/multishell" "$helper_entitlements"
sign "$identity" "$app" "$entitlements"
codesign --verify "$app" || echo "warning: $app is not validly signed" >&2

echo "built $app ($version, $commit)"
