import SwiftUI
import AppKit

struct WelcomeView: View {
    @StateObject private var modelManager = ModelManager()
    @AppStorage("transcriptionProvider") private var transcriptionProvider = TranscriptionProvider.local.rawValue
    @AppStorage("selectedWhisperModel") private var selectedWhisperModel = WhisperModel.base
    @State private var isDownloadingModel = false
    @Environment(\.dismiss) private var dismiss
    
    private var downloadProgress: Double {
        modelManager.downloadProgress[selectedWhisperModel] ?? 0
    }
    
    private var downloadStage: DownloadStage {
        modelManager.downloadStages[selectedWhisperModel] ?? .preparing
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            ScrollView {
                VStack(spacing: 24) {
                    welcomeSection
                    featuresList
                    setupSection
                }
                .padding(30)
            }
            
            Divider()
            
            actionButtons
                .padding(20)
        }
        .frame(width: 600, height: 650)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)
            
            Text("Welcome to AudioWhisper")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Text("Your AI-powered audio transcription assistant")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding(.top, 30)
        .padding(.bottom, 20)
    }
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy-First Local Transcription")
                        .font(.headline)
                    Text("AudioWhisper uses Apple's Neural Engine to transcribe audio locally on your Mac. Your audio never leaves your device.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            } icon: {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var featuresList: some View {
        let columns = [
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20)
        ]
        
        return LazyVGrid(columns: columns, spacing: 16) {
            FeatureRow(icon: "command", title: "Global Hotkey", description: "Press ⌘⇧Space anywhere to start recording")
            FeatureRow(icon: "waveform", title: "Real-time Audio Levels", description: "Visual feedback while recording")
            FeatureRow(icon: "text.cursor", title: "Auto-Paste", description: "Transcribed text automatically pastes to your active app")
            FeatureRow(icon: "brain", title: "Multiple AI Models", description: "Choose from 6 Whisper models based on your needs")
        }
        .padding(.horizontal, 20) // Add padding to move it right
    }
    
    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Quick Setup")
                .font(.headline)
            
            if isDownloadingModel {
                modelDownloadProgress
            } else {
                setupOptions
            }
            
            accessibilityInstructions
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var modelDownloadProgress: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Downloading Base Model")
                        .font(.headline)
                    Text("This will take about 30-60 seconds...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            ProgressView(value: downloadProgress) {
                HStack {
                    Text(downloadStageText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if downloadProgress > 0 {
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text("The Base model (142MB) provides good accuracy with fast performance.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var downloadStageText: String {
        switch downloadStage {
        case .preparing:
            return "Preparing download..."
        case .downloading:
            return "Downloading model..."
        case .processing:
            return "Processing model files..."
        case .completing:
            return "Almost done..."
        case .ready:
            return "Model ready!"
        case .failed(let error):
            return "Download failed: \(error)"
        }
    }
    
    private var setupOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("AudioWhisper will use local AI transcription by default. No API keys or internet connection required!")
                    .font(.callout)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            Label {
                Text("Want to use cloud services instead? You can switch to OpenAI or Google Gemini in Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var accessibilityInstructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Enable Auto-Paste", systemImage: "hand.raised.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text("To enable automatic pasting of transcribed text:")
                .font(.callout)
            
            VStack(alignment: .leading, spacing: 8) {
                InstructionRow(number: 1, text: "Open System Settings → Privacy & Security → Accessibility")
                InstructionRow(number: 2, text: "Click the '+' button")
                InstructionRow(number: 3, text: "Add AudioWhisper from your Applications folder")
                InstructionRow(number: 4, text: "Make sure the toggle is enabled")
            }
            
            Text("You can do this later if you prefer.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Spacer()
            
            Button("Get Started") {
                startWithLocalWhisper()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDownloadingModel)
        }
    }
    
    
    private func startWithLocalWhisper() {
        // Prevent multiple executions
        guard !isDownloadingModel && !isDismissing else { return }
        
        // Set the settings
        UserDefaults.standard.set(TranscriptionProvider.local.rawValue, forKey: "transcriptionProvider")
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        // Notify that welcome is complete and open settings
        NotificationCenter.default.post(name: NSNotification.Name("WelcomeCompleted"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsRequested"), object: nil)
        
        dismissWindow()
    }
    
    
    @State private var isDismissing = false
    
    private func dismissWindow() {
        // Prevent multiple dismiss attempts
        guard !isDismissing else { return }
        
        isDismissing = true
        
        // Stop the modal - this will return control to WelcomeWindow.showWelcomeDialog()
        NSApplication.shared.stopModal(withCode: .OK)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Fixed-size icon container with centered content
            ZStack {
                Color.clear
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.accentColor)
                    .symbolRenderingMode(.monochrome)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 50) // Ensure consistent height
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.orange)
                .frame(width: 20, alignment: .trailing)
            
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}