#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

SDK="$(xcrun --show-sdk-path --sdk macosx)"
APP="build/后台应用.app"
ICON_PNG="build/AppIcon.png"
ICONSET="build/AppIcon.iconset"

rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET" build

swiftc -O -framework AppKit -o build/make-icon scripts/make-icon.swift
./build/make-icon "$ICON_PNG"

for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"
do
  size="${spec%% *}"
  name="${spec#* }"
  sips -z "$size" "$size" "$ICON_PNG" --out "$ICONSET/$name" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp Info.plist "$APP/Contents/Info.plist"

swiftc -parse-as-library -O -swift-version 5 \
  -sdk "$SDK" \
  -target arm64-apple-macos14.0 \
  -framework AppKit \
  -framework SwiftUI \
  -framework ServiceManagement \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/BackgroundApps"

codesign --force --sign - --identifier local.backgroundapps "$APP"

echo "---- dump ----"
"$APP/Contents/MacOS/BackgroundApps" --dump > build/dump.txt
tail -n 1 build/dump.txt

if pgrep -x BackgroundApps >/dev/null; then
  killall BackgroundApps || true
  sleep 0.4
fi

DEST="$HOME/Applications/后台应用.app"
rm -rf "$DEST"
cp -R "$APP" "$DEST"
codesign --force --sign - --identifier local.backgroundapps "$DEST"
xattr -cr "$DEST" || true
echo "installed $DEST"
