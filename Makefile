# Day-to-day entry points. Each is a thin wrapper; the real work is in
# SwiftPM and Scripts/make-app.sh, so CI and the Makefile cannot drift.

CONFIG ?= debug
APP     = build/Multishell.app
INSTALL_DIR ?= /Applications

.PHONY: build release test test-app lint format install run clean signing-identity

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
test:
	swift test
	swift test --package-path Apps/macOS

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

## Rewrite files in place to the project style (.swift-format).
format:
	swift format --in-place --recursive Sources Tests Apps/macOS/Sources Apps/macOS/Tests Package.swift Apps/macOS/Package.swift

## Build and launch the debug bundle.
run: build
	open "$(APP)"

clean:
	rm -rf build .build Apps/macOS/.build
