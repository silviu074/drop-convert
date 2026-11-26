#!/bin/bash
# Builds Drop Convert on this Mac from DropConvert.swift and puts it in ~/Applications. No admin rights needed.
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/Drop Convert.app"

if [ ! -f "$HERE/DropConvert.swift" ]; then echo 'Unzip the whole folder first, then run the installer from inside it.'; exit 1; fi

# The Swift compiler comes with Apple's free Command Line Tools.
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Drop Convert is built on your Mac with Apple's free Command Line Tools, which are not installed yet."
  echo 'A window from Apple opens now: click Install, wait until it finishes, then run this installer again.'
  xcode-select --install
  exit 0
fi

echo 'Building Drop Convert (this can take a minute) ...'
pkill -x DropConvert 2>/dev/null
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if ! xcrun swiftc -O -swift-version 5 "$HERE/DropConvert.swift" -o "$APP/Contents/MacOS/DropConvert"; then
  rm -rf "$APP"
  echo 'The build failed. Paste the text above into Claude Code and ask it to fix DropConvert.swift.'
  exit 1
fi
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Drop Convert</string>
  <key>CFBundleIdentifier</key><string>local.dropconvert</string>
  <key>CFBundleExecutable</key><string>DropConvert</string>
  <key>CFBundleIconFile</key><string>app</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
sips -s format icns "$HERE/app.png" --out "$APP/Contents/Resources/app.icns" >/dev/null 2>&1 || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

# ffmpeg does video, audio and images. Documents and PDFs work without it.
FF=''
for p in /opt/homebrew/bin/ffmpeg /usr/local/bin/ffmpeg /opt/local/bin/ffmpeg; do [ -x "$p" ] && FF="$p"; done
if [ -z "$FF" ]; then
  echo ''
  echo 'Video, audio and images need ffmpeg (free). It is not installed yet.'
  BREW=''
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$p" ] && BREW="$p"; done
  if [ -n "$BREW" ]; then
    read -r -p 'Install it now with Homebrew? (y/n) ' answer
    case "$answer" in y*|Y*) "$BREW" install ffmpeg ;; esac
  else
    echo 'To add it later: install Homebrew from https://brew.sh, then run: brew install ffmpeg'
  fi
fi

echo ''
echo 'Tip: with the free LibreOffice installed, documents turn into PDFs that look closer to the original.'
echo 'Done. Drop Convert starts now; next time open it from Launchpad or Spotlight.'
echo 'To remove it later, run "Uninstall Drop Convert.command".'
open "$APP"
