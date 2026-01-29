#!/bin/bash

# Change to repo root (parent of scripts/)
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

# Suppress macOS system framework noise (Contacts, CoreData XPC, FrontBoardServices)
# These errors occur because xctest runs outside the app sandbox
export OS_ACTIVITY_MODE=disable

# Run all tests
# Run tests sequentially to prevent flaky tests from shared UserDefaults state
swift test --no-parallel -Xswiftc -DTESTING 2>&1 | grep -v -E "(CNAccountCollection|ContactsPersistence|com\.apple\.contacts|NSXPCConnection|DetachedSignatures|FrontBoardServices|NSStatusItemScene|BSBlockSentinel)" | grep -E "(Test Suite|Test Case|passed|failed|error:|Executed|skipped)"