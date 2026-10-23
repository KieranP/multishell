#!/bin/bash
# Creates the self-signed certificate local builds are signed with. Run once.
# Why a certificate, and each step's quirk: Docs/design/signing.md.
set -euo pipefail

name="${1:-Multishell Dev}"
# Asked for, since it is `login.keychain` on an account old enough. Printed
# indented and quoted; only that is stripped, a home being free to hold spaces.
keychain="$(security login-keychain | sed -e 's/^[[:space:]]*//' -e 's/^"\(.*\)"$/\1/')"

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

# Security.framework will not verify an empty-password PKCS#12; this one
# guards nothing secret (signing.md).
password="$(openssl rand -hex 16)"

# The old algorithms, since Security.framework cannot read OpenSSL 3's PBES2
# and SHA-256 MAC defaults either (signing.md).
run openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" \
    -name "$name" -out "$work/identity.p12" -passout "pass:$password" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1

# -A, or codesign raises a keychain dialog on every build until the user
# answers "Always Allow".
security import "$work/identity.p12" -k "$keychain" -P "$password" -T /usr/bin/codesign -A

# Trusted for code signing alone, in the user's domain; a refusal is not fatal,
# and no -k, which would add a second copy (signing.md).
if ! security add-trusted-cert -r trustRoot -p codeSign "$work/cert.pem"; then
    echo "warning: $name was not marked trusted for code signing" >&2
fi

echo "created $name"

# Signs a probe now, while a failure is still about this script, and prints
# the requirement grants will be keyed to (signing.md).
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
# `|| true`, or a requirement printed in another shape fails the grep and,
# under `pipefail`, a script that has already done its work.
codesign -d -r- "$work/probe" 2>/dev/null | grep designated || true
