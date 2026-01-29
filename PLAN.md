# Fix Remaining Test Compilation Errors

## Problem Summary

The test suite has multiple compilation errors due to API changes in the main codebase that weren't reflected in the tests.

---

## Error Categories and Fixes

### 1. TranscriptionProvider String vs Enum (180 occurrences)

**Issue:** Tests pass string literals like `"openai"` instead of enum values like `.openai`

**Files affected:**
- `Tests/Performance/PerformanceTests.swift` (line 35)
- `Tests/EdgeCases/ServiceEdgeCaseTests.swift` (lines 92, 103, 113, 123, 133, 143, 154, 165)
- `Tests/Views/Transcription/TranscriptionRecordRowTests.swift` (lines 13, 31, 50, 112, 121, 130, 142, 151, 166, 214)

**Fix:** Change `provider: "openai"` to `provider: .openai`, `provider: "gemini"` to `provider: .gemini`, etc.

---

### 2. AppStatus Enum Argument Labels (20+ occurrences)

**Issue:** Tests use `message:` argument label which was removed. Current API:
- `.error(String)` not `.error(message: String)`
- `.processing(String)` not `.processing(message: String)`

**Files affected:**
- `Tests/Waveform/WaveformViewsTests.swift` (lines 144, 168, 279, 327)
- `Tests/UISnapshotTests.swift` (lines 291, 311)
- `Tests/Views/Components/Effects/StateTransitionEffectsTests.swift` (lines 161, 172)

**Fix:** Remove `message:` label from `.error()` and `.processing()` calls.

---

### 3. ResumedFlag Not in Scope (30+ occurrences)

**Issue:** `ResumedFlag` is declared as `private` in `PasteManager.swift`. Tests can't access it.

**Files affected:**
- `Tests/ContentViewPasteTests.swift` (lines 9, 22, 52, 53)
- `Tests/Views/ContentViewPasteCoordinationTests.swift` (lines 219, 226, 234, 235, 249)

**Fix:** Change `ResumedFlag` from `private` to `internal` in `Sources/Managers/PasteManager.swift` (line 52).

---

### 4. MLXModel.name Property Missing (3 occurrences)

**Issue:** Tests access `.name` but the property is `displayName`

**Files affected:**
- `Tests/Views/Dashboard/MLXModelManagementViewTests.swift` (lines 59, 156)
- `Tests/Models/ModelEntryTests.swift` (line 268)

**Fix:** Change `.name` to `.displayName`

---

### 5. GlassBackgroundTests MockContext Issues (110+ occurrences)

**Issue:** Tests try to create mock `NSViewRepresentableContext` which is not possible - it's a framework type that can't be mocked this way.

**Files affected:**
- `Tests/Views/Components/Effects/GlassBackgroundTests.swift` (entire file)

**Fix:** Delete the problematic MockContext structures and rewrite tests to not require mocking the context. The tests should focus on what can actually be tested (the view creation, properties, etc.) without requiring a mock context.

---

### 6. AppDelegateExtensionTests MainActor Isolation (50+ occurrences)

**Issue:** Tests call MainActor-isolated methods from non-isolated context.

**Files affected:**
- `Tests/AppDelegateExtensionTests.swift` (lines 10, 11, 16, 68, 69, 85, 86, 93, 94)

**Fix:** Add `@MainActor` annotation to the test class or wrap calls in `await MainActor.run {}`.

---

### 7. AudioProcessor/FFTProcessor Not in Scope (2 occurrences)

**Issue:** Tests reference types that don't exist in the codebase.

**Files affected:**
- `Tests/Performance/PerformanceTests.swift` (lines 10, 18)

**Fix:** Remove or comment out these tests since the types don't exist.

---

### 8. ModelEntryTests Enum Member Issues

**Issue:** Tests reference enum members that don't exist or have wrong types.

**Files affected:**
- `Tests/Models/ModelEntryTests.swift` (lines 149, 159)

**Fix:** Update to use correct enum cases and values.

---

## Files to Modify

1. `Sources/Managers/PasteManager.swift` - Make `ResumedFlag` internal
2. `Tests/Performance/PerformanceTests.swift` - Fix provider, remove AudioProcessor tests
3. `Tests/EdgeCases/ServiceEdgeCaseTests.swift` - Fix provider strings
4. `Tests/Views/Transcription/TranscriptionRecordRowTests.swift` - Fix provider strings
5. `Tests/Waveform/WaveformViewsTests.swift` - Remove `message:` labels
6. `Tests/UISnapshotTests.swift` - Remove `message:` labels
7. `Tests/Views/Components/Effects/StateTransitionEffectsTests.swift` - Remove `message:` labels
8. `Tests/ContentViewPasteTests.swift` - Will work after ResumedFlag fix
9. `Tests/Views/ContentViewPasteCoordinationTests.swift` - Will work after ResumedFlag fix
10. `Tests/Views/Dashboard/MLXModelManagementViewTests.swift` - Change `.name` to `.displayName`
11. `Tests/Models/ModelEntryTests.swift` - Fix `.name` and enum members
12. `Tests/Views/Components/Effects/GlassBackgroundTests.swift` - Remove MockContext, rewrite tests
13. `Tests/AppDelegateExtensionTests.swift` - Add `@MainActor` annotation

---

## Verification

After all fixes:
1. Run `swift build --target AudioWhisperTests` to verify compilation
2. Run `swift test --parallel` to verify tests pass
