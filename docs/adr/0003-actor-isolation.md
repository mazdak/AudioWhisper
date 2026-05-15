# ADR 0003: Actor & MainActor Isolation Strategy

**Status:** Accepted
**Date:** 2026-05-14

## Context

The app coordinates audio capture (real-time thread), Python subprocesses, network calls, and SwiftUI state. Different concurrency tools are appropriate for each.

## Decision

- **`@MainActor`:** SwiftUI Views, ViewModels (`RecordingViewModel`), AppDelegate, and Stores that publish UI-bound state.
- **`actor` (custom):** Long-lived shared state that must be isolated without forcing the main thread. Examples: `WhisperKitCache` (model cache inside `LocalWhisperService`), `MLDaemonManager`.
- **Plain `class` + `NSLock` / `DispatchQueue`:** Audio-thread hot paths (`AudioEngineRecorder` buffer access). Locks are cheaper than actor hops at audio-callback frequency.

`@Published` properties on otherwise non-MainActor classes are individually `@MainActor`-isolated.

## Consequences

- Audio capture stays off the main thread (post-G3 fix; see grade report).
- Service-layer code is naturally async/await; no callback pyramids.
- Test code must use `await` to read actor state — adds boilerplate but eliminates a class of data races.
