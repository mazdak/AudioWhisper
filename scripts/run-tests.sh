#!/usr/bin/env bash
set -euo pipefail
# Run the AudioWhisper test suite with macOS framework noise filtered out.
# Runs in parallel by default to match CI. Tests that touch
# UserDefaults.standard should subclass IsolatedXCTestCase
# (Tests/Utilities/IsolatedXCTestCase.swift). Pass --no-parallel to debug
# flakes locally.
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n 's/^# //p' "$0" | head -n 20
  exit 0
fi

# Change to repo root (parent of scripts/)
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

# Suppress macOS system framework noise (Contacts, CoreData XPC, FrontBoardServices)
# These errors occur because xctest runs outside the app sandbox
export OS_ACTIVITY_MODE=disable

# Run all tests in parallel by default (matches CI). Pass --no-parallel
# as a script arg to fall back to sequential execution when debugging flakes.
PARALLEL_FLAG="--parallel"
for arg in "$@"; do
  if [[ "$arg" == "--no-parallel" ]]; then
    PARALLEL_FLAG="--no-parallel"
  fi
done

swift test $PARALLEL_FLAG -Xswiftc -DTESTING 2>&1 | grep -v -E "(CNAccountCollection|ContactsPersistence|com\.apple\.contacts|NSXPCConnection|DetachedSignatures|FrontBoardServices|NSStatusItemScene|BSBlockSentinel)" | grep -E "(Test Suite|Test Case|passed|failed|error:|Executed|skipped)"