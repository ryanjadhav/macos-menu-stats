#!/bin/bash
set -euo pipefail

APP_NAME="MenuBarStats"
BUILD_DIR=".build/release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Assembling ${APP_NAME}.app..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
cp "${BUILD_DIR}/${APP_NAME}"  "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist"      "${APP_BUNDLE}/Contents/Info.plist"

echo "Done: ${APP_BUNDLE}"
