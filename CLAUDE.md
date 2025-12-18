# AudioWhisper — LLM Assistant Guidelines

This document provides instructions for AI assistants (e.g., ChatGPT, Claude) on how to work effectively with the AudioWhisper codebase. Follow these guidelines when analyzing, proposing changes, or implementing features.

## 1. Purpose and Scope

- **Primary Role**: Assist developers by reading existing code, suggesting idiomatic Swift implementations, writing tests, and fixing bugs.
- **Focus Areas**:
  - Adherence to Swift and SwiftUI best practices
  - Memory safety and thread correctness
  - Consistent use of existing libraries and patterns
  - Comprehensive test coverage

## 2. Libraries and Frameworks

AudioWhisper relies on:
- **SwiftUI** + **AppKit** for UI and macOS menu bar integration
- **AVFoundation** for audio recording
- **Alamofire** for HTTP requests and model downloads
- **WhisperKit** (CoreML) for local transcription
- **HotKey** for global keyboard shortcuts
- **Combine** / Swift Concurrency for asynchronous logic
- **KeychainAccess** for secure API key storage

When extending functionality, prefer these existing dependencies over introducing new ones.

## 3. Code Style and Best Practices

- **Swift 5.7+** targeting **macOS 14+** (use modern APIs).
- Avoid force unwrapping (`!`); prefer `guard let` and optional chaining.
- Use value types (`struct`/`enum`) by default; reserve `class` for reference semantics or bridging.
- Prevent retain cycles with `[weak self]` or `unowned self` in closures.
- Dispatch UI updates on the main actor or `DispatchQueue.main`.
- Keep functions small (≤ 40 lines) and single-purpose.
- Write concise comments only for non-obvious logic; favor self-documenting code.
- Follow existing naming conventions, file structure, and grouping.

## 4. Testing

- Write **XCTest** unit tests for all new or modified logic.
- Cover edge cases, error paths, and concurrency scenarios.
- Ensure `swift test --parallel --enable-code-coverage` passes without failures.
- Keep tests deterministic and isolate external dependencies with mocks.

## 5. Memory Safety and Concurrency

- Use Swift Concurrency (`async`/`await`) or Combine for asynchronous flows.
- Prevent data races: confine shared state to actors or serial queues.
- Clean up observers, timers, and resources in `deinit` or task cancellation.
- Annotate UI components with `@MainActor` when required.

## 6. Pull Request Guidelines for AI Outputs

- Provide minimal, focused patches for the requested change.
- Run `swift build`, `swift test`, and any linting checks before submitting.
- Do not introduce unrelated changes or fix pre-existing warnings.
- Include a brief rationale and testing steps in the PR description.

## 7. Building and Deploying

### Quick Build & Deploy

```bash
# 1. Build the app bundle
make build

# 2. If make build fails after "Build succeeded", run manually:
cd /Users/yesh/Documents/personal/reference/AudioWhisper
swift build -c release --arch arm64 --arch x86_64

# Create app bundle manually if needed:
rm -rf AudioWhisper.app
mkdir -p AudioWhisper.app/Contents/{MacOS,Resources,Resources/bin}
cp .build/apple/Products/Release/AudioWhisper AudioWhisper.app/Contents/MacOS/
chmod +x AudioWhisper.app/Contents/MacOS/AudioWhisper

# Copy Python scripts and ml/ package
cp Sources/*.py AudioWhisper.app/Contents/Resources/ 2>/dev/null || true
cp -R Sources/ml AudioWhisper.app/Contents/Resources/ 2>/dev/null || true
find AudioWhisper.app/Contents/Resources/ml -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Copy uv binary
cp "$(command -v uv)" AudioWhisper.app/Contents/Resources/bin/uv 2>/dev/null || true

# Generate Info.plist (see scripts/build.sh for full template)
# Generate icons
./scripts/generate-icons.sh
iconutil -c icns AudioWhisper.iconset -o AudioWhisper.app/Contents/Resources/AppIcon.icns

# 3. Sign with stable identifier
codesign --force --deep --sign - --identifier "com.audiowhisper.app" AudioWhisper.app

# 4. Deploy
pkill -x AudioWhisper 2>/dev/null || true
sleep 1
rm -rf /Applications/AudioWhisper.app
cp -R AudioWhisper.app /Applications/

# 5. Launch
open /Applications/AudioWhisper.app
```

### Accessibility Permission (SmartPaste)

**Critical**: The app uses adhoc code signing. When replacing the app bundle, macOS invalidates existing Accessibility permissions because the code signature hash changes.

After deploying a new build, the user must:
1. Open **System Settings → Privacy & Security → Accessibility**
2. **Remove** AudioWhisper from the list (select it, click `-`)
3. **Re-add** it (click `+`, navigate to `/Applications/AudioWhisper.app`)
4. Ensure the toggle is **ON**

Without this, SmartPaste will silently fail (paste won't work).

### Troubleshooting

- **"Build succeeded" then "Build failed"**: The Swift build works but post-build steps fail. Check if `.build/apple/Products/Release/AudioWhisper` exists and run bundle creation manually.
- **SmartPaste broken after deploy**: Re-grant Accessibility permission (see above).
- **App won't launch**: Check `codesign -dvvv /Applications/AudioWhisper.app` for signing issues.

---

*This file is intended solely for guiding AI assistants. Do not expose it in end-user documentation.*
