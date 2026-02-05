#!/bin/bash
set -e

echo "Compiling tests..."
swiftc -o Tests/RunTests \
    BrewMenuBar/BrewService.swift \
    Tests/main.swift

echo "Running tests..."
./Tests/RunTests
echo "Done."
