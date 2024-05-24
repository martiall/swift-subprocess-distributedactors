#!/bin/sh

set -e

mkdir -p .plugins/

swift package resolve

swift package clean

TOOLCHAINS=org.swiftwasm.202451 swift build --product EnglishGreeter \
    --triple wasm32-unknown-wasi --static-swift-stdlib -c release
TOOLCHAINS=org.swiftwasm.202451 swift build --product FrenchGreeter \
    --triple wasm32-unknown-wasi --static-swift-stdlib -c release

cp .build/release/*.wasm .plugins/

swift package clean

SWIFT6_TOOLCHAIN="/Library/Developer/Toolchains/swift-DEVELOPMENT-SNAPSHOT-2024-05-15-a.xctoolchain"

TOOLCHAINS=org.swift.59202405151a swift build --product FrenchGreeter -c release
TOOLCHAINS=org.swift.59202405151a swift build --product EnglishGreeter -c release

cp .build/release/FrenchGreeter .plugins/
cp .build/release/EnglishGreeter .plugins/

TOOLCHAINS=org.swift.59202405151a swift build --product Host -c release

DYLD_LIBRARY_PATH=${SWIFT6_TOOLCHAIN}/usr/lib/swift/macosx \
    .build/release/Host \
    -p .plugins/EnglishGreeter .plugins/FrenchGreeter \
    -w .plugins/EnglishGreeter.wasm .plugins/FrenchGreeter.wasm