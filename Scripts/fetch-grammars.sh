#!/bin/bash
# Downloads each tree-sitter grammar at its pin into .build/grammars, where
# Package.swift names it by path. Why archives and not git: dependencies.md.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/Scripts/build-lib.sh"

output="$root/.build/grammars"
lock_file="$root/.build/grammars.lock"

# Package identity, repository, the tag it was taken at, the commit, and the
# SHA-256 of GitHub's archive of that commit. A bump changes all three.
pins=(
    "tree-sitter-bash tree-sitter/tree-sitter-bash v0.25.1 a06c2e4415e9bc0346c6b86d401879ffb44058f7 879e8951ea2cc82455407e3eda0293319657ec53e83191e0fb5a67430d10d804"
    "tree-sitter-c tree-sitter/tree-sitter-c v0.24.2 b780e47fc780ddc8da13afa35a3f4ed5c157823d dc3979e40fce678c27273ba8ab93b48b5acd6b91d1dfde6a4451222d366d689f"
    "tree-sitter-c-sharp tree-sitter/tree-sitter-c-sharp v0.23.5 cac6d5fb595f5811a076336682d5d595ac1c9e85 e4cd8a1c118a1e176931e9e0a635fc55e3d0f69e1649e40b74d72bda918e948d"
    "tree-sitter-cpp tree-sitter/tree-sitter-cpp v0.23.4 f41e1a044c8a84ea9fa8577fdd2eab92ec96de02 ad4b9b56602e9b14082637988f0042521006819960ed8c308bc24ded9ceb9331"
    "tree-sitter-css tree-sitter/tree-sitter-css v0.25.0 dda5cfc5722c429eaba1c910ca32c2c0c5bb1a3f c47392e483feb9137d8f0acf9ca6e916b820122c260324454a9980c75c98c3c5"
    "tree-sitter-go tree-sitter/tree-sitter-go v0.25.0 1547678a9da59885853f5f5cc8a99cc203fa2e2c a71543d63f82b917457f47a3f6dbecd8087592fabc49a757da82c3e00c0e93de"
    "tree-sitter-html tree-sitter/tree-sitter-html v0.23.2 5a5ca8551a179998360b4a4ca2c0f366a35acc03 5a198c1bb13ad848ccf2b91dca3d8ac39af63f4da98ad4814b8e27107889eb94"
    "tree-sitter-java tree-sitter/tree-sitter-java v0.23.5 94703d5a6bed02b98e438d7cad1136c01a60ba2c 39dea56cc3bb5fb1658f79b195a92b6f08885886bca636adf2dc6243af641c47"
    "tree-sitter-javascript tree-sitter/tree-sitter-javascript v0.25.0 44c892e0be055ac465d5eeddae6d3e194424e7de a13fa28148e41bb939b2c2b8cd73c4b4295273b70cbac55a7a589020f52b9611"
    "tree-sitter-json tree-sitter/tree-sitter-json v0.24.8 ee35a6ebefcef0c5c416c0d1ccec7370cfca5a24 9e4a7391cc3a9f4b87b382956dd01bc1f99fb1afcdc86b2c152c8a1bd14444d5"
    "tree-sitter-kotlin fwcd/tree-sitter-kotlin 0.3.8 e1a2d5ad1f61f5740677183cd4125bb071cd2f30 2046cb900ba359119db534f79de090310a81f33a7870a141d549c3caa9d71c6c"
    "tree-sitter-make tree-sitter-grammars/tree-sitter-make v1.1.1 5e9e8f8ff3387b0edcaa90f46ddf3629f4cfeb1d 4fbeedc40982964d357f79eb27de65065b561904de16d07b15ee155c67bfc85c"
    "tree-sitter-markdown tree-sitter-grammars/tree-sitter-markdown v0.5.3 f969cd3ae3f9fbd4e43205431d0ae286014c05b5 45ec28324b75ec80788775a6aed26888f55b306981fede9cbe35d7348ae80469"
    "tree-sitter-php tree-sitter/tree-sitter-php v0.25.1 58d5643086ae60e93a3746cca648363ee97c8761 139701b185691b6f82d81ef6387de5cfe23b7833a75fa1eeca9b80416aa58039"
    "tree-sitter-python tree-sitter/tree-sitter-python v0.25.0 293fdc02038ee2bf0e2e206711b69c90ac0d413f b74d8ba6730535354175436208fe1452fd464f235263959ca40b8bf32cb23dc6"
    "tree-sitter-ruby tree-sitter/tree-sitter-ruby v0.23.1 71bd32fb7607035768799732addba884a37a6210 e520d4cda2805db82b5a44ec84ba048e30d91770851b4a173490e0d45e4cb555"
    "tree-sitter-rust tree-sitter/tree-sitter-rust v0.24.2 77a3747266f4d621d0757825e6b11edcbf991ca5 dee82ddfd01bfc3a8ed201cc03b56448107d3217a4b3a7a8fc7fa6bc32b2405b"
    "tree-sitter-scss tree-sitter-grammars/tree-sitter-scss v1.0.0 eb69c8f55ecc17235f43358c65ec644578554f92 ef20116762b36bb59736fe772a858bde9c784ad1cc66d1787cdf24aa033f5a49"
    "tree-sitter-sql DerekStride/tree-sitter-sql gh-pages 39fdb006403747241244326e8af3b3e96b85381c 3926262684353dff4979c451c9db80e81918cab94cbd3842117e3ea4fbaa4941"
    "tree-sitter-svelte tree-sitter-grammars/tree-sitter-svelte v1.0.2 774a65aea563accc35f5d45fafa4d96ec5761f57 1d0976d8fcf7fa421574086dfe4eb0293080e75cdb9794cf6dacdd9c0769fb1c"
    "tree-sitter-swift alex-pinkus/tree-sitter-swift 0.7.4-with-generated-files 82bb3a533e0801fd2bbaa11dc49676e10bf41948 1cec20e92ddee958bbc1b19ff4251bff2b4618e9e55c33a45a0c56ceaa889a5c"
    "tree-sitter-toml tree-sitter-grammars/tree-sitter-toml v0.7.0 64b56832c2cffe41758f28e05c756a3a98d16f41 feeb2e1cf531588cdcfb9c57292620151a08597f18a98dad26cc17fd4b544dcb"
    "tree-sitter-typescript tree-sitter/tree-sitter-typescript v0.23.2 f975a621f4e7f532fe322e13c4f79495e0a7b2e7 4de2e82e557810eecb93cb3b31fbb3bd28ba4c91ba9a6c6164bcaa074125b7b5"
    "tree-sitter-yaml tree-sitter-grammars/tree-sitter-yaml v0.7.2 7708026449bed86239b1cd5bce6e3c34dbca6415 6e8cb69a4f7a05478b1143d38bd10df2163170a6678df1848f3be89c8b7c5f3b"
    "tree-sitter-zig tree-sitter-grammars/tree-sitter-zig v1.1.2 b670c8df85a1568f498aa5c8cae42f51a90473c0 c7af5b1a992fcaffdf50a11a9974fbf8f09d20c4d9ef42245ac90c152dd3a85a"
)

# Two at once, `make test` beside `make run`, would each replace the folder
# the other is extracting into.
hold_lock() {
    mkdir -p "$root/.build"
    if [ -z "${MULTISHELL_GRAMMARS_LOCKED-}" ] && command -v lockf >/dev/null; then
        MULTISHELL_GRAMMARS_LOCKED=1 exec lockf -k "$lock_file" "$root/Scripts/fetch-grammars.sh" "$@"
    fi
}

# Written last, so a folder a killed fetch left behind never passes for its pin.
stamp() {
    printf '%s\n' "$1/.fetched"
}

is_fetched() {
    local identity="$1" sha256="$2"
    [ "$(cat "$(stamp "$output/$identity")" 2>/dev/null)" = "$sha256" ]
}

fetch() {
    local identity="$1" repository="$2" revision="$3" sha256="$4"
    local archive="$output/.$identity.tar.gz" partial="$output/.$identity.partial"
    local url="https://codeload.github.com/$repository/tar.gz/$revision" actual
    curl -fsSL --retry 3 -o "$archive" "$url" || die "error: could not download $url."
    actual="$(shasum -a 256 "$archive" | cut -d' ' -f1)"
    if [ "$actual" != "$sha256" ]; then
        rm -f "$archive"
        die "error: $url has SHA-256 $actual," \
            "       not the $sha256 pinned in Scripts/fetch-grammars.sh."
    fi
    rm -rf "$partial"
    mkdir -p "$partial"
    tar -xzf "$archive" -C "$partial" --strip-components 1
    printf '%s\n' "$sha256" > "$(stamp "$partial")"
    rm -rf "${output:?}/$identity" "$archive"
    mv "$partial" "$output/$identity"
}

remove_unpinned() {
    local directory identity pin kept
    for directory in "$output"/*/; do
        [ -d "$directory" ] || continue
        identity="$(basename "$directory")"
        kept=0
        for pin in "${pins[@]}"; do
            [ "${pin%% *}" = "$identity" ] && kept=1
        done
        [ "$kept" = 1 ] || rm -rf "$directory"
    done
}

hold_lock "$@"
mkdir -p "$output"
remove_unpinned
pids=()
for pin in "${pins[@]}"; do
    read -r identity repository _ revision sha256 <<< "$pin"
    is_fetched "$identity" "$sha256" && continue
    fetch "$identity" "$repository" "$revision" "$sha256" &
    pids+=("$!")
done
failed=0
for pid in "${pids[@]+"${pids[@]}"}"; do
    wait "$pid" || failed=1
done
[ "$failed" = 0 ] || die "error: some grammars were not fetched; see above."
[ "${#pids[@]}" = 0 ] || echo "fetched ${#pids[@]} grammars into $output"
