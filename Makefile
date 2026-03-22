APP_NAME    = MenuBarStats
BUNDLE_NAME = $(APP_NAME).app
BUILD_DIR   = .build/release
APP_DIR     = $(BUILD_DIR)/$(BUNDLE_NAME)

.PHONY: all build app clean

all: app

## Build the release binary via Swift Package Manager
build:
	swift build -c release

## Assemble a proper .app bundle from the release binary
app: build
	@echo "Assembling $(BUNDLE_NAME)..."
	@mkdir -p "$(APP_DIR)/Contents/MacOS"
	@mkdir -p "$(APP_DIR)/Contents/Resources"
	@cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	@cp "Resources/Info.plist"     "$(APP_DIR)/Contents/Info.plist"
	@echo "Done: $(APP_DIR)"

## Remove all build artifacts
clean:
	swift package clean
	@rm -rf "$(BUILD_DIR)/$(BUNDLE_NAME)"
