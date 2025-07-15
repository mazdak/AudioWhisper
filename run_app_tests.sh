#!/bin/bash

# Run just the AudioWhisperAppTests
swift test --filter "AudioWhisperAppTests/test" 2>&1 | grep -E "(Test Case|passed|failed|error:|Executed)"