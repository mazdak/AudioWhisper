# ADR 0001: Ship Unsandboxed (Developer ID Signed + Notarized)

**Status:** Accepted
**Date:** 2026-05-14

## Context

AudioWhisper's core features require capabilities that the macOS App Sandbox does not grant or grants only with severe limitations:

- **Press-and-hold push-to-talk** requires monitoring modifier-key state via `CGEventTap` — sandbox blocks this without an entitlement that the App Store does not approve for general apps.
- **Smart Paste** posts synthetic `⌘V` events via `CGEvent.postToPid` — same restriction.
- **Prompt overrides** at `~/Library/Application Support/AudioWhisper/prompts/` use direct filesystem access — sandbox would force this through `NSOpenPanel`, breaking the silent-override UX.
- **Global hotkeys** via the `HotKey` library use Carbon APIs that sandbox treats with restrictions.

## Decision

Ship as a Developer ID–signed, notarized app, *not* sandboxed. Distribute via direct download and Homebrew cask.

## Consequences

- **Cannot ship via the Mac App Store.** Distribution is direct + brew.
- **Notarization is mandatory** for every release. `scripts/build.sh --notarize` handles it.
- **Code signature changes invalidate Accessibility permission** — users must re-grant after each install. Documented in README.
- **Higher security responsibility:** without the sandbox safety net, we must be careful about subprocess execution, file paths, and bundled binaries (see ADR 0002).
