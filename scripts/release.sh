#!/bin/zsh
# Crea una build di rilascio di Dillo pronta da distribuire: archivio Release, firma,
# notarizzazione Apple e immagine disco (DMG) con collegamento ad Applicazioni.
#
# Uso:
#   scripts/release.sh                 # build locale firmata con il certificato di sviluppo (solo per test)
#   DEVELOPER_ID="Developer ID Application: Nome Cognome (TEAMID)" \
#   NOTARY_PROFILE="dillo-notary" scripts/release.sh   # build distribuibile, firmata e notarizzata
#
# Prerequisiti per la distribuzione:
#   1. Certificato "Developer ID Application" nel portachiavi (Apple Developer Program).
#   2. Profilo notarytool salvato una volta con:
#        xcrun notarytool store-credentials dillo-notary --apple-id <email> --team-id <TEAMID>
#      (chiede una password specifica per app generata su appleid.apple.com)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$PWD
OUT="$ROOT/dist"
BUILD="$ROOT/build/release"
SCHEME=Dillo
APP_NAME=Dillo

command -v xcodegen >/dev/null || { echo "✗ Serve xcodegen: brew install xcodegen"; exit 1; }

VERSION=$(awk '/MARKETING_VERSION:/ {gsub(/"/, "", $2); print $2; exit}' project.yml)
BUILD_NUMBER=$(awk '/CURRENT_PROJECT_VERSION:/ {gsub(/"/, "", $2); print $2; exit}' project.yml)
DMG="$OUT/$APP_NAME-$VERSION.dmg"
echo "▸ Dillo $VERSION ($BUILD_NUMBER)"

rm -rf "$BUILD" && mkdir -p "$BUILD" "$OUT"
xcodegen generate >/dev/null

echo "▸ Test"
xcodebuild test -project Dillo.xcodeproj -scheme "$SCHEME" -derivedDataPath "$BUILD/dd" -quiet

SIGN_ARGS=()
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  echo "▸ Firma con: $DEVELOPER_ID"
  SIGN_ARGS=(CODE_SIGN_IDENTITY="$DEVELOPER_ID" OTHER_CODE_SIGN_FLAGS="--timestamp")
else
  echo "⚠︎ DEVELOPER_ID non impostato: build firmata con il certificato di sviluppo (NON distribuibile)."
fi

echo "▸ Archivio Release"
xcodebuild archive -project Dillo.xcodeproj -scheme "$SCHEME" -configuration Release \
  -archivePath "$BUILD/$APP_NAME.xcarchive" -derivedDataPath "$BUILD/dd" -quiet "${SIGN_ARGS[@]}"

APP="$BUILD/$APP_NAME.app"
ditto "$BUILD/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app" "$APP"
codesign --verify --deep --strict "$APP"
echo "✓ Firma verificata"

notarize() {   # $1 = file da notarizzare (zip o dmg)
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}

if [[ -n "${DEVELOPER_ID:-}" && -n "${NOTARY_PROFILE:-}" ]]; then
  echo "▸ Notarizzazione dell'app"
  ditto -c -k --keepParent "$APP" "$BUILD/$APP_NAME.zip"
  notarize "$BUILD/$APP_NAME.zip"
  xcrun stapler staple "$APP"
fi

echo "▸ Creazione DMG"
STAGE="$BUILD/dmg"
rm -rf "$STAGE" && mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applicazioni"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGE" -ov -format ULFO "$DMG" >/dev/null

if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --sign "$DEVELOPER_ID" --timestamp "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "▸ Notarizzazione del DMG"
    notarize "$DMG"
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature -v "$DMG"
  fi
fi

shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "✓ Pronto: $DMG"
