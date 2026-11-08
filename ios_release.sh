#!/usr/bin/env bash
# Builds the iPhone app on GitHub (macOS) from what's pushed to main, and
# saves it as release/Health-<version>-<build>.ipa, next to the APK. The
# previous .ipa is moved to release/old/. Needs the GitHub CLI (gh),
# logged in. The .ipa is unsigned: install it with e.g.
# `xtool install release/Health-<version>-<build>.ipa`.
set -euo pipefail

cd "$(dirname "$0")"

# Builds go to ../Build (shared with the other version of Health) when
# that folder exists, otherwise to release/.
RELEASE_DIR=release
[[ -d ../Build ]] && RELEASE_DIR=../Build
OLD_DIR=$RELEASE_DIR/old
WORKFLOW=ios.yml

if [[ -n $(git status --porcelain) || $(git rev-parse HEAD) != $(git rev-parse origin/main 2>/dev/null) ]]; then
  echo "Warning: GitHub builds what's pushed to main, not your local changes." >&2
fi

version=$(git show origin/main:pubspec.yaml | grep -E '^version:' | sed -E 's/^version:[[:space:]]*//')
version_name=${version%%+*}
build_number=${version##*+}

echo "==> Building Health ${version_name} (build ${build_number}) for iPhone on GitHub"
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
gh workflow run "$WORKFLOW" --ref main
run_id=""
for _ in $(seq 1 30); do
  run_id=$(gh run list --workflow "$WORKFLOW" --event workflow_dispatch --limit 5 \
    --json databaseId,createdAt -q "[.[] | select(.createdAt >= \"$started\")][0].databaseId")
  [[ -n $run_id ]] && break
  sleep 2
done
[[ -n $run_id ]] || { echo "Couldn't find the new run." >&2; exit 1; }
echo "==> Run: $(gh run view "$run_id" --json url -q .url)"
gh run watch "$run_id" --exit-status --interval 30 > /dev/null

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
gh run download "$run_id" -n Health-ios -D "$tmp"
# Builds stay off GitHub until launch: delete the uploaded copy.
artifact_id=$(gh api "repos/{owner}/{repo}/actions/runs/$run_id/artifacts" -q '.artifacts[0].id')
gh api -X DELETE "repos/{owner}/{repo}/actions/artifacts/$artifact_id"

mkdir -p "$OLD_DIR"
for previous in "$RELEASE_DIR"/Health-*.ipa; do
  [[ -e $previous && $previous != *-store.ipa ]] || continue
  mv "$previous" "$OLD_DIR/"
  echo "==> Moved previous release to $OLD_DIR/$(basename "$previous")"
done

NEW_IPA="$RELEASE_DIR/Health-${version_name}-${build_number}.ipa"
mv "$tmp/Health-unsigned.ipa" "$NEW_IPA"
echo "==> New release: $NEW_IPA ($(du -h "$NEW_IPA" | cut -f1))"
