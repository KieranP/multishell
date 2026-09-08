#!/bin/bash
# Creates the self-signed certificate local builds are signed with. Run once.
#
# macOS keys a privacy grant to the signature's designated requirement, and an
# ad-hoc signature's requirement is a bare cdhash: it changes with every build,
# so every permission the user gave is asked for again and the App Management
# toggle they flipped goes dead. A certificate makes the requirement name the
# certificate instead, which survives a rebuild.
#
# Nothing here is a distribution identity: the certificate is its own root and
# no other machine trusts it. It only stops the local build's identity from
# moving under TCC.
set -euo pipefail

name="${1:-Multishell Dev}"
# Asked for rather than assumed: the login keychain is `login.keychain` on an
# account old enough, and `login.keychain-db` since Sierra.
keychain="$(security login-keychain | tr -d ' "')"

if security find-certificate -c "$name" >/dev/null 2>&1; then
    echo "already present: $name"
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Reports what openssl said, which `set -e` alone would swallow.
run() {
    if ! output="$("$@" 2>&1)"; then
        echo "$1 $2 failed: $output" >&2
        exit 1
    fi
}

# codeSigning in the extended key usage is what makes codesign accept it as an
# identity; a certificate without it is found and then refused.
run openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$work/key.pem" -out "$work/cert.pem" \
    -subj "/CN=$name" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning"

# A password on a file that lives for the rest of this script and is then
# deleted, because Security.framework will not verify the MAC of an empty-
# password PKCS#12 at all: it reports the file as a wrong password whoever
# wrote it. Nothing it protects is a secret; the certificate is public and the
# key is about to be in the keychain.
password="$(openssl rand -hex 16)"

# The old algorithms on purpose. OpenSSL 3 defaults a PKCS#12 bundle to PBES2
# and a SHA-256 MAC, which Security.framework cannot read either, and reports
# the same way. Both OpenSSL 3 and the LibreSSL that ships as /usr/bin/openssl
# accept these flags.
run openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" \
    -name "$name" -out "$work/identity.p12" -passout "pass:$password" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1

# -A because the alternative is codesign raising a keychain dialog on every
# build until the user answers "Always Allow".
security import "$work/identity.p12" -k "$keychain" -P "$password" -T /usr/bin/codesign -A

# The certificate is its own issuer, so nothing vouches for it unless the user
# does. Trust is set for code signing alone, in the user's own domain: no
# administrator rights, and nothing outside signing is affected. macOS asks for
# the login password here. Not fatal if it is refused: codesign signs with an
# untrusted identity anyway, and only `codesign --verify` minds.
#
# No -k: that flag adds the certificate to a keychain, which the import above
# already did, and a second copy under the same name would make
# `codesign --sign "Multishell Dev"` ambiguous and fail.
if ! security add-trusted-cert -r trustRoot -p codeSign "$work/cert.pem"; then
    echo "warning: $name was not marked trusted for code signing" >&2
fi

echo "created $name"

# Sign something here, where a failure is still about this script, rather than
# leaving the first build to discover it. It also answers the keychain's
# "codesign wants to use a key" dialog now instead of mid-build, and prints the
# requirement the whole exercise is for: a certificate rather than a cdhash,
# which is what a permission the user grants will survive a rebuild by.
if ! printf 'int main(void){return 0;}' | cc -x c - -o "$work/probe" 2>/dev/null; then
    echo "note: no compiler, so the identity was not test-signed" >&2
    exit 0
fi
if ! output="$(codesign --force --sign "$name" "$work/probe" 2>&1)"; then
    echo "warning: the certificate exists but codesign will not use it:" >&2
    echo "         $output" >&2
    exit 1
fi
echo "signs with it. A grant will now be keyed to:"
# `|| true`, or a requirement printed in some other shape would fail the grep
# and, under `set -e` and `pipefail`, fail a script that has already done its
# work.
codesign -d -r- "$work/probe" 2>/dev/null | grep designated || true
