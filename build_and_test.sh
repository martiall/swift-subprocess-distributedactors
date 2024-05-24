#!/bin/sh

mkdir -p .plugins/

SWIFT6_TOOLCHAIN="/Library/Developer/Toolchains/swift-6.0-DEVELOPMENT-SNAPSHOT-2024-04-14-a.xctoolchain"

TOOLCHAINS=org.swift.600202404141a swift build --product FrenchGreeter -c release
TOOLCHAINS=org.swift.600202404141a swift build --product EnglishGreeter -c release

cp .build/release/FrenchGreeter .plugins/
cp .build/release/EnglishGreeter .plugins/

TOOLCHAINS=org.swift.600202404141a swift build --product Host -c release

DYLD_LIBRARY_PATH=${SWIFT6_TOOLCHAIN}/usr/lib/swift/macosx \
    .build/release/Host \
    -p .plugins/EnglishGreeter .plugins/FrenchGreeter