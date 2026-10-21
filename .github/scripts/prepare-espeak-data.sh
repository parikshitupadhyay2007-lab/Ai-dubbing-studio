#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SOURCE="$ROOT/android/android/app/src/main/cpp/espeak-ng"
ASSETS="$ROOT/android/android/app/src/main/assets"
BUILD="$(mktemp -d)"

trap 'rm -rf "$BUILD"' EXIT

if [[ ! -f "$SOURCE/CMakeLists.txt" ]]; then
    echo "ERROR: Run prepare-espeak.sh first."
    exit 1
fi

command -v cmake >/dev/null || {
    echo "ERROR: CMake is required."
    exit 1
}

echo "Compiling eSpeak NG language data on Linux..."

cmake \
    -S "$SOURCE" \
    -B "$BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_LIBSONIC=OFF \
    -DUSE_LIBPCAUDIO=OFF \
    -DUSE_MBROLA=OFF \
    -DUSE_SPEECHPLAYER=OFF \
    -DUSE_ASYNC=OFF \
    -DBUILD_TESTING=OFF

cmake --build "$BUILD" --target data --parallel 2

DATA="$BUILD/espeak-ng-data"

for file in phondata phonindex phontab intonations en_dict hi_dict; do
    if [[ ! -s "$DATA/$file" ]]; then
        echo "ERROR: Missing compiled data: $file"
        exit 1
    fi
done

mkdir -p "$ASSETS"
rm -rf "$ASSETS/espeak-ng-data"

cp -R "$DATA" "$ASSETS/espeak-ng-data"

echo "eSpeak NG language data prepared successfully."
