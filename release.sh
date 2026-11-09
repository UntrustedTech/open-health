#!/usr/bin/env bash
# Builds a release APK into release/Health-<version>-<build>.apk.
# The previous APK is moved to release/old/, and the build number in
# pubspec.yaml is bumped so the new APK installs as an update. The iPhone
# build is made by ios_release.sh.
set -euo pipefail

cd "$(dirname "$0")"
export PATH="$HOME/flutter/bin:$PATH"

# Builds go to ../Build or ../../Build (shared with the other version of Health) when
# that folder exists, otherwise to release/.
RELEASE_DIR=release
for d in ../../Build ../Build; do [[ -d $d ]] && RELEASE_DIR=$d; done
OLD_DIR=$RELEASE_DIR/old
NEW_VERSION_FILE=release/new.version
BUILT_APK=build/app/outputs/flutter-apk/app-release.apk

mkdir -p "$OLD_DIR"

version=$(grep -E '^version:' pubspec.yaml | sed -E 's/^version:[[:space:]]*//')
version_name=${version%%+*}
build_number=${version##*+}

# The current APK (named new.apk by older versions of this script), not
# the store version's.
current_apk=$(ls "$RELEASE_DIR"/Health-*.apk "$RELEASE_DIR"/new.apk 2>/dev/null | grep -v -- -store | head -1 || true)

previous_build=""
if [[ -n $current_apk ]]; then
  previous_build=$(cat "$NEW_VERSION_FILE" 2>/dev/null || echo "$build_number")
  # Next build number: one past the last release (or pubspec's, if already higher).
  build_number=$(( previous_build + 1 > build_number ? previous_build + 1 : build_number ))
  sed -i -E "s/^version:.*/version: ${version_name}+${build_number}/" pubspec.yaml
fi

echo "==> Checking code and running tests"
flutter analyze
flutter test

echo "==> Building Health ${version_name} (build ${build_number})"
# Obfuscated, to make the app harder to reverse engineer. The symbols
# needed to read crash stack traces are kept per build (not in git).
SYMBOLS_DIR=$RELEASE_DIR/symbols/v$(printf '%03d' "$build_number")
# Phones only: x86_64 is for emulators and would add about 30 MB.
flutter build apk --release --obfuscate --split-debug-info="$SYMBOLS_DIR" \
  --target-platform android-arm,android-arm64 \
  --dart-define=SOURCE_CODE_URL="${SOURCE_CODE_URL:-}"

if [[ -n $current_apk ]]; then
  archived="$OLD_DIR/$(basename "$current_apk")"
  if [[ $current_apk == */new.apk ]]; then
    stamp=$(date -r "$current_apk" +%Y-%m-%d)
    archived="$OLD_DIR/Health_${stamp}_v$(printf '%03d' "$previous_build").apk"
  fi
  mv "$current_apk" "$archived"
  echo "==> Moved previous release to $archived"
fi

NEW_APK="$RELEASE_DIR/Health-${version_name}-${build_number}.apk"
cp "$BUILT_APK" "$NEW_APK"
echo "$build_number" > "$NEW_VERSION_FILE"
echo "==> New release: $NEW_APK (v$(printf '%03d' "$build_number"), $(du -h "$NEW_APK" | cut -f1))"
