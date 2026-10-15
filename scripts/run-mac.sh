#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --jobs 2
elemental_bin_dir=$(swift build -c release --show-bin-path)
elemental_app="$PWD/build/ElementalCube.app"
mkdir -p "$elemental_app/Contents/MacOS" "$elemental_app/Contents/Resources"
cp "$elemental_bin_dir/ElementalCube" "$elemental_app/Contents/MacOS/ElementalCube"
cp -R "$elemental_bin_dir/ElementalCube_ElementalCube.bundle" "$elemental_app/Contents/Resources/"
cat > "$elemental_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ElementalCube</string>
<key>CFBundleIdentifier</key><string>local.elementalcube.playground</string>
<key>CFBundleName</key><string>ElementalCube</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
elemental_build=$(python3 -c 'import re;from pathlib import Path;print(re.search(r"CURRENT_PROJECT_VERSION:\s*[^0-9]*(\d+)",Path("project.yml").read_text())[1])')
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $elemental_build" "$elemental_app/Contents/Info.plist"
codesign --force --sign - "$elemental_app"
if [[ "${ELEMENTAL_SKIP_OPEN:-0}" != 1 ]]; then open "$elemental_app"; fi
