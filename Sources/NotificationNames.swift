import Foundation

// MARK: - Typed Notification Names
// This file provides type-safe notification names to avoid typos and improve code completion

extension Notification.Name {
    // MARK: - Settings and Configuration
    static let openSettingsRequested = Notification.Name("OpenSettingsRequested")
    static let updateGlobalHotkey = Notification.Name("UpdateGlobalHotkey")
    
    // MARK: - Welcome Flow
    static let welcomeCompleted = Notification.Name("WelcomeCompleted")
    
    // MARK: - Recording Events
    static let recordingStartFailed = Notification.Name("RecordingStartFailed")
    static let recordingStopped = Notification.Name("RecordingStopped")
    static let targetAppStored = Notification.Name("TargetAppStored")
    static let transcriptionProgress = Notification.Name("TranscriptionProgress")
    
    // MARK: - Window Management
    static let restoreFocusToPreviousApp = Notification.Name("RestoreFocusToPreviousApp")
    
    // MARK: - Keyboard Events
    static let spaceKeyPressed = Notification.Name("SpaceKeyPressed")
    static let escapeKeyPressed = Notification.Name("EscapeKeyPressed")
    static let returnKeyPressed = Notification.Name("ReturnKeyPressed")
    
    // MARK: - Error Handling and Retry
    static let retryRequested = Notification.Name("RetryRequested")
    static let retryTranscriptionRequested = Notification.Name("RetryTranscriptionRequested")
    static let showAudioFileRequested = Notification.Name("ShowAudioFileRequested")
    
    // MARK: - Paste Operations
    static let pasteOperationFailed = Notification.Name("PasteOperationFailed")
    static let pasteOperationSucceeded = Notification.Name("PasteOperationSucceeded")
}