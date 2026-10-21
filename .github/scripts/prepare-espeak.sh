#!/usr/bin/env bash

set -euo pipefail

ESPEAK_VERSION="1.52.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CPP_DIR="$ROOT/android/android/app/src/main/cpp"
DEST="$CPP_DIR/espeak-ng"

URL="https://github.com/espeak-ng/espeak-ng/archive/refs/tags/${ESPEAK_VERSION}.tar.gz"

mkdir -p "$CPP_DIR"

TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

ARCHIVE="$TEMP_DIR/espeak-ng.tar.gz"
EXTRACT_DIR="$TEMP_DIR/source"

mkdir -p "$EXTRACT_DIR"

echo "Preparing eSpeak NG ${ESPEAK_VERSION}"

if [[ -e "$DEST" ]]; then
    if [[ -f "$DEST/CMakeLists.txt" ]] &&
       [[ -f "$DEST/src/include/espeak-ng/speak_lib.h" ]]; then
        echo "Existing eSpeak NG source found."
        exit 0
    fi

    echo "ERROR: Existing eSpeak NG directory is incomplete."
    exit 1
fi

echo "Downloading official source archive..."

curl \
    --fail \
    --location \
    --retry 3 \
    --connect-timeout 30 \
    --output "$ARCHIVE" \
    "$URL"

echo "Checking archive..."

tar -tzf "$ARCHIVE" > /dev/null

tar \
    -xzf "$ARCHIVE" \
    -C "$EXTRACT_DIR"

SOURCE="$EXTRACT_DIR/espeak-ng-${ESPEAK_VERSION}"

if [[ ! -f "$SOURCE/CMakeLists.txt" ]]; then
    echo "ERROR: eSpeak NG CMakeLists.txt missing."
    exit 1
fi

if [[ ! -f "$SOURCE/src/include/espeak-ng/speak_lib.h" ]]; then
    echo "ERROR: eSpeak NG API header missing."
    exit 1
fi

mv "$SOURCE" "$DEST"

echo "eSpeak NG source preparation completed."
