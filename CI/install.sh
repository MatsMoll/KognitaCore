#!/usr/bin/env bash

git clone https://github.com/realm/SwiftLint.git
cd SwiftLint
swift build -c release --static-swift-stdlib
mv .build/x86_64-unknown-linux/release/swiftlint /usr/local/bin/
cd ..
rm -rf SwiftLint

swift package resolve
swift package clean

export DATABASE_DB=postgres
export DATABASE_USER=postgres
