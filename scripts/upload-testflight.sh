#!/usr/bin/env bash
# Upload the latest PadelNote archive to App Store Connect / TestFlight.
# Prerequisite: create the ASC app record first (bundle ID com.farcasmc.padelnote).
# See docs/TESTFLIGHT.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE="$ROOT/build/PadelNote.xcarchive"
EXPORT_DIR="$ROOT/build/export"
UPLOAD_OPTS="$ROOT/build/UploadOptions.plist"

if [[ ! -d "$ARCHIVE" ]]; then
  echo "Missing archive at $ARCHIVE — archive with:"
  echo "  xcodebuild -scheme PadelNote -configuration Release -destination 'generic/platform=iOS' -allowProvisioningUpdates -archivePath build/PadelNote.xcarchive archive"
  exit 1
fi

cat > "$UPLOAD_OPTS" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>8C5FKN2L72</string>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
EOF

mkdir -p "$EXPORT_DIR"
echo "Uploading $ARCHIVE to App Store Connect…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$UPLOAD_OPTS" \
  -allowProvisioningUpdates

echo "Upload finished. Check App Store Connect → TestFlight for processing."
