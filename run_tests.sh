#!/bin/bash
set -e

echo "Compiling tests..."
swiftc -o Tests/RunTests \
    BrewMenuBar/BrewService.swift \
    BrewMenuBar/CommandRunner.swift \
    Tests/main.swift

echo "Running tests..."
./Tests/RunTests
echo "Done."
