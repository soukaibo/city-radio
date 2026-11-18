#!/bin/bash
set -e
cd "$(dirname "$0")"
APP="城市电台.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>城市电台</string>
    <key>CFBundleDisplayName</key><string>城市电台</string>
    <key>CFBundleExecutable</key><string>CityRadio</string>
    <key>CFBundleIdentifier</key><string>com.marvis.cityradio</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>本地自建，无广告无追踪</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key><true/>
    </dict>
</dict>
</plist>
PLIST

cp stations.json "$APP/Contents/Resources/stations.json"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp menuicon.png "$APP/Contents/Resources/menuicon.png"

swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 \
  -o /tmp/CityRadio_arm64 \
  src/main.swift src/Models.swift src/UI.swift \
  -framework Cocoa -framework AVFoundation -framework Carbon

swiftc -swift-version 5 -O -target x86_64-apple-macosx13.0 \
  -o /tmp/CityRadio_x86_64 \
  src/main.swift src/Models.swift src/UI.swift \
  -framework Cocoa -framework AVFoundation -framework Carbon

lipo -create /tmp/CityRadio_arm64 /tmp/CityRadio_x86_64 -output "$APP/Contents/MacOS/CityRadio"
chmod +x "$APP/Contents/MacOS/CityRadio"

codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "BUILD OK"
ls -lh "$APP/Contents/MacOS/CityRadio" | awk '{print $5, $9}'
