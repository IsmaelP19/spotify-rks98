#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
app=".build/RK S98.app"
mkdir -p "$app/Contents/MacOS"
cat > "$app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>rk-s98-menu</string>
	<key>CFBundleIdentifier</key>
	<string>com.local.rk-s98-spotify</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleDisplayName</key>
	<string>RK S98</string>
	<key>CFBundleName</key>
	<string>RK S98</string>
	<key>CFBundleShortVersionString</key>
	<string>1.1</string>
	<key>CFBundleVersion</key>
	<string>2</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>NSInputMonitoringUsageDescription</key>
	<string>RK S98 abre el teclado para enviar la carátula a su pantalla.</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
EOF
xcrun swiftc -warnings-as-errors -framework AppKit -framework CoreGraphics -framework CoreText -framework ImageIO \
    src/display/TrackInfo.swift src/display/CanvasLayout.swift src/display/Renderer.swift \
    src/spotify/LocalProvider.swift src/app/DryRun.swift src/app/Daemon.swift src/app/MenuCard.swift src/app/MenuBarMain.swift \
    src/keyboard/TftUpload.swift src/keyboard/TftTransport.swift \
    -o "$app/Contents/MacOS/rk-s98-menu"
xcrun swiftc -warnings-as-errors -framework CoreText -framework ImageIO -framework CoreGraphics -framework UniformTypeIdentifiers scripts/render-app-icon.swift -o .build/render-app-icon
.build/render-app-icon "$app/Contents/Resources"
installed="$HOME/Applications/RK S98.app"
mkdir -p "$HOME/Applications"
rm -rf "$installed"
ditto "$app" "$installed"
codesign --force --sign - "$installed"
