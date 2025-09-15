# ContainerManager — AI Assistant Guidelines

This repository hosts a Swift-based macOS menu bar application for managing Apple Containers using the Virtualization framework. The following conventions apply when modifying the codebase.

## Swift Conventions
- Target Swift 5.9 and macOS 14 or later.
- Prefer SwiftUI + AppKit for UI components.
- Avoid force unwrapping (`!`); use `guard let` or optional chaining.
- Keep functions small (≤40 lines) and focused.
- Dispatch UI updates on the main actor.
- Use value types (`struct`/`enum`) unless reference semantics are required.

## Concurrency & Safety
- Use Swift Concurrency (`async`/`await`) for asynchronous work.
- Prevent retain cycles with `[weak self]` or `unowned` captures.
- Clean up tasks and resources appropriately.

## Testing
- Provide XCTest coverage for new logic.
- Run `swift build` and `swift test` before committing.

## Pull Requests
- Keep changes minimal and self‑contained.
- Include a concise summary and testing notes in PRs.

---
This file is for AI assistants and should not appear in end-user documentation.
