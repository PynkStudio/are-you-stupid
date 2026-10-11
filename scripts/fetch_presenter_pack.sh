#!/usr/bin/env bash
# Downloads the published presenter pack (manifest + every clip) into
# tvos/TVResources/PresenterPack/ so the release ships an offline baseline.
# The board still syncs newer revisions at runtime; this only sets the floor.
# Run before a release build: docs/Development/Release Checklist.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/tvos/Config/Presenter.xcconfig"
SECRETS="$ROOT/tvos/Config/Presenter.secrets.xcconfig"
OUT="$ROOT/tvos/TVResources/PresenterPack"
LOCALES=("${@:-en it fr es pt de}")

[[ -f "$SECRETS" ]] || { echo "missing $SECRETS (see docs/Development/Multiplayer Development.md)" >&2; exit 1; }
BASE_URL="$(sed -n 's/^AYS_PRESENTER_BACKEND_URL = //p' "$CONFIG" | sed 's#\$()##')"
TOKEN="$(sed -n 's/^AYS_PRESENTER_API_TOKEN = //p' "$SECRETS")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rm -rf "$OUT" && mkdir -p "$OUT"

for LOCALE in ${LOCALES[@]}; do
  curl -fsS -H "Authorization: Bearer $TOKEN" \
    "$BASE_URL/api/ays/presenter/pack?locale=$LOCALE&format=1" -o "$TMP/manifest.$LOCALE.json"

python3 - "$TMP/manifest.$LOCALE.json" > "$TMP/clips.txt" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
for variants in m["lines"].values():
    for v in variants:
        if v.get("clip"): print(v["clip"]["sha256"], v["clip"]["bytes"])
PY

while read -r sha bytes; do
  curl -fsS -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/ays/presenter/pack/clips/$sha" -o "$TMP/$sha.mp3"
  [[ "$(shasum -a 256 "$TMP/$sha.mp3" | cut -d' ' -f1)" == "$sha" ]] || { echo "hash mismatch for $sha" >&2; exit 1; }
  [[ "$(wc -c < "$TMP/$sha.mp3" | tr -d ' ')" == "$bytes" ]] || { echo "size mismatch for $sha" >&2; exit 1; }
  done < "$TMP/clips.txt"

  cp "$TMP/manifest.$LOCALE.json" "$OUT"/
  cp "$TMP"/*.mp3 "$OUT"/ 2>/dev/null || true
  echo "presenter pack $LOCALE: revision $(python3 -c "import json;print(json.load(open('$OUT/manifest.$LOCALE.json'))['revision'])"), $(wc -l < "$TMP/clips.txt" | tr -d ' ') clips -> $OUT"
done
