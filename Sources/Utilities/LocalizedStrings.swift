import Foundation

/// Centralized localized strings for AudioWhisper
internal enum LocalizedStrings {
    
    // MARK: - UI States
    enum UI {
        static let ready = NSLocalizedString("ui.ready", 
            value: "Ready", 
            comment: "Status when app is ready to record")
        
        static let recording = NSLocalizedString("ui.recording", 
            value: "Recording...", 
            comment: "Status during audio recording")
        
        static let processing = NSLocalizedString("ui.processing", 
            value: "Processing...", 
            comment: "Status during transcription processing")
        
        static let success = NSLocalizedString("ui.success", 
            value: "Success!", 
            comment: "Status when transcription succeeds")
        
        static let microphoneAccessRequired = NSLocalizedString("ui.microphone_access_required", 
            value: "Microphone access required", 
            comment: "Status when microphone permission is denied")
        
        static let spaceToRecord = NSLocalizedString("ui.space_to_record", 
            value: "Space to Record • Escape to Cancel", 
            comment: "Keyboard shortcut instructions")
    }
    
    // MARK: - Alerts
    enum Alerts {
        static let errorTitle = NSLocalizedString("alerts.error_title", 
            value: "Something went wrong", 
            comment: "Title for error alerts")
        
        static let microphoneAccessTitle = NSLocalizedString("alerts.microphone_access_title", 
            value: "Microphone Access Required", 
            comment: "Title for microphone permission alert")
        
        static let microphoneAccessMessage = NSLocalizedString("alerts.microphone_access_message", 
            value: "AudioWhisper needs microphone access to record audio. Please enable microphone access in System Settings > Privacy & Security > Microphone.", 
            comment: "Message explaining why microphone access is needed")
        
        static let openSystemSettings = NSLocalizedString("alerts.open_system_settings", 
            value: "Open System Settings", 
            comment: "Button to open system settings")
        
        static let cancel = NSLocalizedString("alerts.cancel", 
            value: "Cancel", 
            comment: "Cancel button")
    }
    
    // MARK: - Errors
    enum Errors {
        static let failedToStartRecording = NSLocalizedString("errors.failed_to_start_recording", 
            value: "Can't start recording right now. Please check your microphone permissions and try again.", 
            comment: "Error when recording fails to start")
        
        static let failedToGetRecordingURL = NSLocalizedString("errors.failed_to_get_recording_url", 
            value: "Unable to save your recording. Please try recording again.", 
            comment: "Error when recording URL is unavailable")
        
        static let recordingURLEmpty = NSLocalizedString("errors.recording_url_empty", 
            value: "Recording could not be saved. Please try again.", 
            comment: "Error when recording URL path is empty")
        
        static let transcriptionFailed = NSLocalizedString("errors.transcription_failed", 
            value: "Transcription failed: %@\n\nPlease check your internet connection and API key in Settings.", 
            comment: "Error when transcription fails with specific message")
        
        static let localTranscriptionFailed = NSLocalizedString("errors.local_transcription_failed", 
            value: "Local transcription failed: %@\n\nTry selecting a different model or switching to cloud transcription.", 
            comment: "Error when local transcription fails")
        
        static let fileTooLarge = NSLocalizedString("errors.file_too_large", 
            value: "Your recording is too long. Please record shorter audio clips (under 25MB).", 
            comment: "Error when audio file exceeds size limit")
        
        static let invalidAudioFile = NSLocalizedString("errors.invalid_audio_file", 
            value: "Recording appears to be corrupted. Please try recording again.", 
            comment: "Error when audio file URL is invalid")
        
        static let apiKeyMissing = NSLocalizedString("errors.api_key_missing", 
            value: "To use %@ transcription, please add your API key in Settings (⌘,).", 
            comment: "Error when API key is missing, %@ is the provider name")
        
        static let fileUploadFailed = NSLocalizedString("errors.file_upload_failed", 
            value: "Unable to upload your recording: %@\n\nPlease check your internet connection and try again.", 
            comment: "Error when file upload fails")
    }
    
    // MARK: - Local Whisper Errors
    enum LocalWhisper {
        static let modelNotDownloaded = NSLocalizedString("local_whisper.model_not_downloaded", 
            value: "The selected model hasn't been downloaded yet. Please wait for it to finish downloading or choose a different model.", 
            comment: "Error when whisper model is not available")
        
        static let invalidAudioFormat = NSLocalizedString("local_whisper.invalid_audio_format", 
            value: "This audio format isn't supported. Please try recording again.", 
            comment: "Error when audio format is not supported")
        
        static let failedToAllocateBuffer = NSLocalizedString("local_whisper.failed_to_allocate_buffer", 
            value: "Not enough memory to process your audio. Please close other apps and try again.", 
            comment: "Error when audio buffer allocation fails")
        
        static let noAudioChannelData = NSLocalizedString("local_whisper.no_audio_channel_data", 
            value: "No audio was detected in your recording. Please try recording again.", 
            comment: "Error when audio has no channel data")
        
        static let failedToResampleAudio = NSLocalizedString("local_whisper.failed_to_resample_audio", 
            value: "Unable to process your audio. Please try recording again.", 
            comment: "Error when audio resampling fails")
    }
    
    // MARK: - Menu Items
    enum Menu {
        static let record = NSLocalizedString("menu.record", 
            value: "Record", 
            comment: "Menu item to start recording")
        
        static let settings = NSLocalizedString("menu.settings", 
            value: "Settings...", 
            comment: "Menu item to open settings")
        
        static let quit = NSLocalizedString("menu.quit", 
            value: "Quit", 
            comment: "Menu item to quit the app")
        
        static let closeWindow = NSLocalizedString("menu.close_window", 
            value: "Close Window", 
            comment: "Menu item to close current window")
        
        static let history = NSLocalizedString("menu.history", 
            value: "History...", 
            comment: "Menu item to open transcription history")
    }
    
    // MARK: - Settings
    enum Settings {
        static let title = NSLocalizedString("settings.title", 
            value: "AudioWhisper Settings", 
            comment: "Settings window title")
    }
    
    // MARK: - Accessibility
    enum Accessibility {
        static let microphoneIcon = NSLocalizedString("accessibility.microphone_icon", 
            value: "AudioWhisper", 
            comment: "Accessibility description for microphone icon")
        
        static let recordingButton = NSLocalizedString("accessibility.recording_button", 
            value: "Recording button", 
            comment: "Accessibility description for main recording button")
        
        static let progressIndicator = NSLocalizedString("accessibility.progress_indicator", 
            value: "Download progress", 
            comment: "Accessibility label for download progress indicators")
        
        static let modelDownloadStatus = NSLocalizedString("accessibility.model_download_status", 
            value: "Model download status", 
            comment: "Accessibility label for model download status indicators")
    }
}