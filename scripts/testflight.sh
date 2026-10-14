#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-prepare}"
case "$mode" in prepare|validate|upload) ;; *) echo 'Usage: scripts/testflight.sh [prepare|validate|upload]' >&2; exit 2 ;; esac
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
release_dir="${ELEMENTAL_RELEASE_DIR:-build/testflight}"
mkdir -p "$release_dir"
if [ "$mode" = prepare ]; then
    python3 scripts/asc.py prepare-signing
    xcodebuild -project ElementalCube.xcodeproj -scheme ElementalCube-iOS -configuration Release \
        -destination 'generic/platform=iOS' -archivePath "$release_dir/ElementalCube.xcarchive" \
        -derivedDataPath "$release_dir/DerivedData" CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY='Apple Distribution' PROVISIONING_PROFILE_SPECIFIER='ElementalCube App Store' \
        CURRENT_PROJECT_VERSION="${ELEMENTAL_BUILD_NUMBER:-1}" archive
    xcodebuild -exportArchive -archivePath "$release_dir/ElementalCube.xcarchive" \
        -exportPath "$release_dir/Export" -exportOptionsPlist ExportOptions.plist
else
    # Authentication is loaded locally and never printed or committed.
    if [ -f "${ASC_ENV_FILE:-$HOME/.private_keys/appstoreconnect.env}" ]; then
        set -a
        source "${ASC_ENV_FILE:-$HOME/.private_keys/appstoreconnect.env}"
        set +a
    fi
    : "${ASC_KEY_ID:?Set ASC_KEY_ID}"
    : "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID}"
    export API_PRIVATE_KEYS_DIR="$(dirname "${ASC_KEY_PATH:-$HOME/.private_keys/AuthKey_${ASC_KEY_ID}.p8}")"
    if [ "$mode" = validate ]; then
        xcrun altool --validate-app "$release_dir/Export/ElementalCube-iOS.ipa" \
            --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID"
    else
        xcrun altool --upload-package "$release_dir/Export/ElementalCube-iOS.ipa" \
            --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID"
    fi
fi
