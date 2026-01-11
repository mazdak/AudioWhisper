import AppKit
import os.log

internal extension AppDelegate {
    func configureShortcutMonitors() {
        pressAndHoldMonitor?.stop()
        pressAndHoldMonitor = nil
        isHoldRecordingActive = false

        let newConfiguration = PressAndHoldSettings.configuration()
        pressAndHoldConfiguration = newConfiguration

        guard newConfiguration.enabled else { return }

        let keyUpHandler: (() -> Void)? = (newConfiguration.mode == .hold) ? { [weak self] in
            self?.handlePressAndHoldKeyUp()
        } : nil

        let monitor = PressAndHoldKeyMonitor(
            configuration: newConfiguration,
            keyDownHandler: { [weak self] in
                self?.handlePressAndHoldKeyDown()
            },
            keyUpHandler: keyUpHandler
        )

        pressAndHoldMonitor = monitor
        monitor.start()
    }

    private func handlePressAndHoldKeyDown() {
        switch pressAndHoldConfiguration.mode {
        case .hold:
            startRecordingFromPressAndHold()
        case .toggle:
            handleHotkey(source: .pressAndHold)
        }
    }

    private func handlePressAndHoldKeyUp() {
        guard pressAndHoldConfiguration.mode == .hold else { return }
        stopRecordingFromPressAndHold()
    }

    private func startRecordingFromPressAndHold() {
        guard let recorder = audioRecorder else { return }

        if recorder.isRecording {
            isHoldRecordingActive = true
            return
        }

        if !recorder.hasPermission {
            showRecordingWindowForProcessing()
            return
        }

        // Store the current frontmost app for paste functionality in silent mode
        let silentExpressMode = UserDefaults.standard.bool(forKey: "silentExpressMode")
        if silentExpressMode {
            storePreviousAppForPaste()
        }

        if recorder.startRecording() {
            isHoldRecordingActive = true
            updateMenuBarIcon(isRecording: true)
            SoundManager().playRecordingStartSound()
        } else {
            isHoldRecordingActive = false
            showRecordingWindowForProcessing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(
                        name: .recordingStartFailed,
                        object: nil
                    )
                }
            }
        }
    }

    private func stopRecordingFromPressAndHold() {
        guard isHoldRecordingActive else {
            return
        }
        guard let recorder = audioRecorder, recorder.isRecording else {
            isHoldRecordingActive = false
            return
        }

        isHoldRecordingActive = false
        updateMenuBarIcon(isRecording: false)

        let silentExpressMode = UserDefaults.standard.bool(forKey: "silentExpressMode")

        if silentExpressMode {
            // Silent mode: use the direct transcription service without UI
            let targetApp = WindowController.storedTargetApp
            Task {
                await SilentTranscriptionService.shared.performSilentTranscription(
                    audioRecorder: recorder,
                    targetApp: targetApp
                )
            }
        } else {
            // Normal mode: show the window for visual feedback
            showRecordingWindowForProcessing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(name: .spaceKeyPressed, object: nil)
                }
            }
        }
    }

    func handleHotkey(source: HotkeyTriggerSource) {
        if source == .standardHotkey && pressAndHoldConfiguration.enabled {
            return
        }

        let immediateRecording = UserDefaults.standard.bool(forKey: "immediateRecording")
        let silentExpressMode = UserDefaults.standard.bool(forKey: "silentExpressMode")

        if immediateRecording {
            guard let recorder = audioRecorder else {
                Logger.app.error("AudioRecorder not available for immediate recording")
                toggleRecordWindow()
                return
            }

            if recorder.isRecording {
                updateMenuBarIcon(isRecording: false)

                if silentExpressMode {
                    // Silent mode: use the direct transcription service without UI
                    let targetApp = WindowController.storedTargetApp
                    Task {
                        await SilentTranscriptionService.shared.performSilentTranscription(
                            audioRecorder: recorder,
                            targetApp: targetApp
                        )
                    }
                } else {
                    // Normal mode: show the window for visual feedback
                    if recordingWindow == nil || recordingWindow?.isVisible == false {
                        toggleRecordWindow()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        NotificationCenter.default.post(name: .spaceKeyPressed, object: nil)
                    }
                }
            } else {
                if !recorder.hasPermission {
                    toggleRecordWindow()
                    return
                }

                // Store the current frontmost app before starting recording
                // This is needed for paste functionality in silent mode
                if silentExpressMode {
                    storePreviousAppForPaste()
                }

                if recorder.startRecording() {
                    updateMenuBarIcon(isRecording: true)
                    SoundManager().playRecordingStartSound()
                } else {
                    toggleRecordWindow()
                    NotificationCenter.default.post(
                        name: .recordingStartFailed,
                        object: nil
                    )
                }
            }
        } else {
            toggleRecordWindow()
        }
    }

    private func storePreviousAppForPaste() {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            WindowController.storedTargetApp = frontmostApp
            NotificationCenter.default.post(name: .targetAppStored, object: frontmostApp)
        }
    }

    private func updateMenuBarIcon(isRecording: Bool) {
        guard let button = statusItem?.button else { return }

        if isRecording {
            startRecordingAnimation()
        } else {
            stopRecordingAnimation()
            button.image = AppSetupHelper.createMenuBarIcon()
        }
    }

    private func startRecordingAnimation() {
        guard let button = statusItem?.button else { return }

        stopRecordingAnimation()

        let iconSize = AppSetupHelper.getAdaptiveMenuBarIconSize()
        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)

        let redImage = NSImage(systemSymbolName: "microphone.circle", accessibilityDescription: "Recording")?.withSymbolConfiguration(config)
        redImage?.isTemplate = false
        let redOutlineImage = redImage?.tinted(with: .systemRed)

        let blackImage = NSImage(systemSymbolName: "microphone.circle", accessibilityDescription: "Recording")?.withSymbolConfiguration(config)
        blackImage?.isTemplate = true

        button.image = redOutlineImage

        var isRedState = true

        let queue = DispatchQueue(label: "com.audiowhisper.animation", qos: .background)
        let timer = DispatchSource.makeTimerSource(queue: queue)

        timer.schedule(deadline: .now(), repeating: 0.5)

        timer.setEventHandler { [weak button] in
            guard let button = button else { return }

            isRedState.toggle()

            Task { @MainActor in
                button.image = isRedState ? redOutlineImage : blackImage
            }
        }

        recordingAnimationTimer = timer
        timer.resume()
    }

    private func stopRecordingAnimation() {
        recordingAnimationTimer?.cancel()
        recordingAnimationTimer = nil
    }

    @objc func onRecordingStopped() {
        updateMenuBarIcon(isRecording: false)
    }
}
