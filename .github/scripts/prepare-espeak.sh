
#!/usr/bin/env bash

set -euo pipefail

ESPEAK_VERSION="1.52.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CPP_DIR="$ROOT/android/android/app/src/main/cpp"

DEST="$CPP_DIR/espeak-ng"

ARCHIVE="$RUNNER_TEMP/espeak-ng.tar.gz"

URL="https://github.com/espeak-ng/espeak-ng/archive/refs/tags/${ESPEAK_VERSION}.tar.gz"

echo "Preparing eSpeak NG ${ESPEAK_VERSION}"

if [ -d "$DEST" ]; then
    echo "eSpeak NG directory already exists."
    exit 0
fi

mkdir -p "$CPP_DIR"

curl \
    --fail \
    --location \
    --retry 3 \
    --output "$ARCHIVE" \
    "$URL"

tar \
    -xzf "$ARCHIVE" \
    -C "$CPP_DIR"

mv \
    "$CPP_DIR/espeak-ng-${ESPEAK_VERSION}" \
    "$DEST"

test -f "$DEST/CMakeLists.txt"

test -f "$DEST/src/include/espeak-ng/speak_lib.h"

echo "eSpeak NG source prepared successfully."
