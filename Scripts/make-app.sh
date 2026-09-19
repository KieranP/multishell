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

package="$root/Apps/macOS"
app="$root/build/Multishell.app"
resources="$package/Sources/Multishell/Resources"
app_derived="$package/.build/xcode"
app_build="$app_derived/Build/Products/$configuration"
cli_derived="$root/.build/xcode"
cli_build="$cli_derived/Build/Products/$configuration"

version="$(bundle_version "$root")"
commits="$(bundle_build_number "$root")"
variant="$(bundle_variant "$root" "$config")"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Helpers"

# Build, verify, and copy the App
xcode_build "$package" Multishell "$app_derived" "$configuration"
verify_binary "$app_build/Multishell"
cp "$app_build/Multishell" "$app/Contents/MacOS/Multishell"

# Build, verify, and copy the CLI
xcode_build "$root" multishell "$cli_derived" "$configuration"
verify_binary "$cli_build/multishell"
cp "$cli_build/multishell" "$app/Contents/Helpers/multishell"

copy_resource_bundles "$app_build" "$app/Contents/Resources"
cp "$package/Resources/Multishell.icns" "$app/Contents/Resources/Multishell.icns"
# MIT requires each notice to travel with the binary, so the bundle carries
# both licences; THIRD-PARTY-NOTICES.md says which covers what.
cp "$root/LICENSE" "$app/Contents/Resources/LICENSE"
cp "$root/THIRD-PARTY-NOTICES.md" "$app/Contents/Resources/THIRD-PARTY-NOTICES.md"
copy_info_plist_strings "$resources" "$app/Contents/Resources"

render_template "$package/Resources/Info.plist.in" \
    @VERSION@ "$version" \
    @BUILD@ "$commits" \
    @VARIANT@ "$variant" \
    @COPYRIGHT@ "$(bundle_copyright)" \
    @LOCALIZATIONS@ "$(bundle_localizations "$resources")" \
    > "$app/Contents/Info.plist"

identity="$(signing_identity)"
sign "$identity" "$app/Contents/Helpers/multishell"
sign "$identity" "$app"
codesign --verify "$app" || echo "warning: $app is not validly signed" >&2

echo "built $app ($version)"
