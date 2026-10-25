PROJECT       := Little Fingers.xcodeproj
SCHEME        := Little Fingers
APP_NAME      := Little Fingers.app
CONFIGURATION ?= Release
BUILD_DIR     := build
DERIVED_DATA  := $(BUILD_DIR)/DerivedData
PRODUCT       := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/$(APP_NAME)
INSTALL_DIR   ?= /Applications
SIGN_IDENTITY ?= Little Fingers Local Signing

XCODEBUILD := xcodebuild \
	-project "$(PROJECT)" \
	-scheme "$(SCHEME)" \
	-configuration $(CONFIGURATION) \
	-derivedDataPath "$(DERIVED_DATA)" \
	-destination 'generic/platform=macOS'

.PHONY: all build debug release run install uninstall zip dmg clean signing-cert help

all: build

help:
	@echo "Targets:"
	@echo "  build      Build the app ($(CONFIGURATION) by default; override with CONFIGURATION=Debug)"
	@echo "  debug      Build the Debug configuration"
	@echo "  release    Build the Release configuration"
	@echo "  run        Build and launch the app"
	@echo "  install    Build and copy the app to $(INSTALL_DIR)"
	@echo "  uninstall  Remove the app from $(INSTALL_DIR)"
	@echo "  zip        Build and package the app as build/Little-Fingers.zip"
	@echo "  dmg        Build and package the app as build/Little-Fingers.dmg"
	@echo "  clean      Remove build artifacts"
	@echo "  signing-cert  Create the local signing certificate (once)"

# Re-sign with a stable certificate so macOS keeps the Accessibility permission
# across rebuilds; falls back to the ad hoc signature if it doesn't exist.
build:
	$(XCODEBUILD) build
	@if security find-certificate -c "$(SIGN_IDENTITY)" >/dev/null 2>&1; then \
		codesign --force --deep --sign "$(SIGN_IDENTITY)" "$(PRODUCT)"; \
		echo "Signed with \"$(SIGN_IDENTITY)\""; \
	else \
		echo "warning: \"$(SIGN_IDENTITY)\" not found, app is signed ad hoc (run make signing-cert)"; \
	fi
	@echo "Built: $(PRODUCT)"

debug:
	@$(MAKE) build CONFIGURATION=Debug

release:
	@$(MAKE) build CONFIGURATION=Release

run: build
	open "$(PRODUCT)"

install: build
	rm -rf "$(INSTALL_DIR)/$(APP_NAME)"
	cp -R "$(PRODUCT)" "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME)"

uninstall:
	rm -rf "$(INSTALL_DIR)/$(APP_NAME)"

zip: build
	ditto -c -k --keepParent "$(PRODUCT)" "$(BUILD_DIR)/Little-Fingers.zip"
	@echo "Packaged: $(BUILD_DIR)/Little-Fingers.zip"

# Disk image with the app and an Applications shortcut for drag-and-drop install.
DMG_STAGING := $(BUILD_DIR)/dmg

dmg: build
	rm -rf "$(DMG_STAGING)" "$(BUILD_DIR)/Little-Fingers.dmg"
	mkdir -p "$(DMG_STAGING)"
	ditto "$(PRODUCT)" "$(DMG_STAGING)/$(APP_NAME)"
	ln -s /Applications "$(DMG_STAGING)/Applications"
	hdiutil create -volname "Little Fingers" -srcfolder "$(DMG_STAGING)" \
		-fs HFS+ -format UDZO -ov "$(BUILD_DIR)/Little-Fingers.dmg"
	rm -rf "$(DMG_STAGING)"
	@echo "Packaged: $(BUILD_DIR)/Little-Fingers.dmg"

clean:
	rm -rf "$(BUILD_DIR)"

signing-cert:
	scripts/create-signing-cert.sh "$(SIGN_IDENTITY)"
