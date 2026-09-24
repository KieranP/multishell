# Day-to-day entry points. Each is a thin wrapper; the real work is in
# SwiftPM and Scripts/make-app.sh, so CI and the Makefile cannot drift.

CONFIG ?= debug
APP     = build/Multishell.app
INSTALL_DIR ?= /Applications

# Several bounds in the suite are wall-clock (waitUntil gives up after 8 s),
# and what makes them fail is a second suite running at the same time in
# another worktree. lockf queues that run instead of letting
# the two oversubscribe the machine; -k keeps the file, which is what gives
# the queue its order. `make test` in a second worktree therefore waits,
# silently, until the first has run. Where there is no lockf, Linux included,
# the suites run unguarded.
TEST_LOCK_FILE ?= $(HOME)/Library/Caches/multishell-test.lock
LOCKF := $(shell command -v lockf 2>/dev/null)
ifneq ($(LOCKF),)
LOCK = $(LOCKF) -k "$(TEST_LOCK_FILE)"
endif

# Tests may write only the build trees and the temporary directories. Why
# --disable-sandbox, and where it runs unconfined: Docs/develop/build.md.
SANDBOX_EXEC := $(shell command -v sandbox-exec 2>/dev/null)
ifneq ($(SANDBOX_EXEC),)
SWIFT_TEST = $(SANDBOX_EXEC) -D REPO="$(CURDIR)" -D HOME="$(HOME)" -f Scripts/test-sandbox.sb swift test --skip-build --disable-sandbox
else
SWIFT_TEST = swift test --skip-build
endif

.PHONY: build release test test-app lint format prettier install run clean signing-identity

## Once per machine: the certificate that keeps the app's privacy permissions.
signing-identity:
	Scripts/make-signing-identity.sh

## Build the app bundle (debug). `make build CONFIG=release` for optimised.
build:
	Scripts/make-app.sh $(CONFIG)

## Build an optimised bundle.
release:
	Scripts/make-app.sh release

## Test everything: the portable libraries and the model, then the Mac hosts.
## Built before the lock and run under it: compiling in two worktrees at once
## is fine, and holding the lock through a full build would queue the slow
## half for nothing.
test:
	swift build --build-tests
	$(LOCK) $(SWIFT_TEST)
	swift build --build-tests --package-path Apps/macOS
	$(LOCK) $(SWIFT_TEST) --package-path Apps/macOS

## Compile the macOS app without bundling; catches SwiftUI errors fast.
test-app:
	swift build --package-path Apps/macOS

## Build release and copy into /Applications (or INSTALL_DIR=...).
install: release
	rm -rf "$(INSTALL_DIR)/Multishell.app"
	cp -R "$(APP)" "$(INSTALL_DIR)/Multishell.app"
	@echo "installed $(INSTALL_DIR)/Multishell.app"

## Report style violations. Same command CI runs; fails on any finding.
lint:
	swift format lint --strict --recursive Sources Tests Apps/macOS/Sources Apps/macOS/Tests Package.swift Apps/macOS/Package.swift

## Rewrite files in place to the project style (.swift-format, .prettierrc).
format: prettier
	swift format --in-place --recursive Sources Tests Apps/macOS/Sources Apps/macOS/Tests Package.swift Apps/macOS/Package.swift
	prettier --write --log-level warn '**/*.md'

## Markdown goes through prettier, which the toolchain does not ship and CI
## does not run.
prettier:
	@command -v prettier >/dev/null || { echo "prettier not found: brew install prettier"; exit 1; }

## Build and launch the debug bundle.
run: build
	open "$(APP)"

clean:
	rm -rf build .build Apps/macOS/.build
