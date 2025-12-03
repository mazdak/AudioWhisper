#!/bin/bash

# Change to repo root (parent of scripts/)
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

# Run just the AudioWhisperAppTests
swift test --filter "AudioWhisperAppTests/test" 2>&1 | grep -E "(Test Case|passed|failed|error:|Executed)"