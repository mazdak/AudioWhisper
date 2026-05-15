# ADR 0004: Migrating `@AppStorage` Views to `AppDefaults`

**Status:** Proposed
**Date:** 2026-05-14

## Context

After Phase 7 of the grade-report sweep, every non-View site reads settings through `AppDefaults` (Sources/Stores/AppDefaults.swift, plus its `+Settings`, `+FeatureFlags`, `+Visual` extensions). However, ~36 SwiftUI views still use `@AppStorage("rawString")` with the same key strings, bypassing `AppDefaults` entirely. This creates two sources of truth for the same keys.

We deferred this migration during the sweep because `@AppStorage` is a property wrapper, not a function call — replacing it requires either:

1. Replacing each `@AppStorage` with explicit `onAppear` / `onChange` plumbing that calls `AppDefaults`, or
2. Building a custom property wrapper that delegates to `AppDefaults`.

Option (2) is dramatically less invasive and preserves SwiftUI's automatic re-render behavior.

## Decision

Introduce a new `@AppDefault` property wrapper in `Sources/Utilities/AppDefault.swift`:

```swift
@propertyWrapper
struct AppDefault<Value>: DynamicProperty {
    private let keyPath: ReferenceWritableKeyPath<AppDefaults.Type, Value>
    @State private var value: Value
    init(_ keyPath: ReferenceWritableKeyPath<AppDefaults.Type, Value>) {
        self.keyPath = keyPath
        self._value = State(initialValue: AppDefaults.self[keyPath: keyPath])
    }
    var wrappedValue: Value {
        get { value }
        nonmutating set { value = newValue; AppDefaults.self[keyPath: keyPath] = newValue }
    }
    var projectedValue: Binding<Value> { Binding(get: { wrappedValue }, set: { wrappedValue = $0 }) }
}
```

Migrate views to:

```swift
@AppDefault(\.transcriptionProvider) var provider
```

## Consequences

- One new utility type to maintain.
- `View.body` re-render behavior should match `@AppStorage` (both wrap `@State`); verify with snapshot tests.
- Need to confirm cross-process synchronization works — `AppDefaults` uses `UserDefaults.standard`, so multiple AudioWhisper instances (unlikely) wouldn't see each other's writes without an explicit notification path. The previous `@AppStorage` had the same limitation.
- Migration is incremental; the two systems can coexist during rollout.
