import SwiftUI
import AppKit

internal struct WelcomeView: View {
    /// Called when the welcome flow is done. `true` = user completed setup, `false` = cancelled.
    var onComplete: (Bool) -> Void = { _ in }

    // The welcome flow always downloads the base model, regardless of any previously saved
    // preference. UserDefaults survive app reinstalls on macOS, so selectedWhisperModel could
    // hold a value the user chose before uninstalling (e.g. largeTurbo). We don't want to
    // surprise them by downloading a large model during first-run setup.
    private let welcomeModel: WhisperModel = .base

    @State private var modelManager = ModelManager.shared
    @AppStorage(AppDefaults.Keys.transcriptionProvider) private var transcriptionProvider = AppDefaults.defaultTranscriptionProvider.rawValue
    @State private var isDownloadingModel = false
    @State private var downloadError: String?
    @Environment(\.dismiss) private var dismiss

    private var downloadStage: DownloadStage {
        modelManager.downloadStages[welcomeModel] ?? .preparing
    }

    private var fileProgress: DownloadFileProgress? {
        modelManager.downloadFileProgress[welcomeModel]
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
                .padding(.vertical, 20)
                .padding(.horizontal, 30)
            }
            
            Divider()
            
            actionButtons
                .padding(20)
        }
        .frame(
            width: LayoutMetrics.Welcome.windowSize.width,
            height: LayoutMetrics.Welcome.windowSize.height
        )
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            Task { await modelManager.refreshModelStates() }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.circle.fill")
                .font(.system(.largeTitle))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
            
            Text("Welcome to AudioWhisper")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Text("Your AI-powered audio transcription assistant")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Text(VersionInfo.fullVersionInfo)
                .font(.caption)
                .foregroundStyle(Color(NSColor.tertiaryLabelColor))
        }
        .padding(.top, 30)
        .padding(.bottom, 8)
    }
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy-First Local Transcription")
                        .font(.headline)
                    Text("AudioWhisper uses Apple's Neural Engine to transcribe audio locally on your Mac. Your audio never leaves your device.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var featuresList: some View {
        let columns = [
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20)
        ]
        
        return LazyVGrid(columns: columns, spacing: 16) {
            FeatureRow(icon: "command", title: "Global Hotkey", description: "Press ⌘⇧Space anywhere (configurable) to record")
            FeatureRow(icon: "waveform", title: "Powerful Transcription", description: "With semantic correction to fix transcription errors intelligently")
            FeatureRow(icon: "clock.arrow.circlepath", title: "Transcription History", description: "Keep track of all your transcriptions with searchable history")
            FeatureRow(icon: "brain", title: "Multiple AI Models", description: "Choose from offline and online models based on your needs")
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

            if let downloadError, !downloadError.isEmpty {
                Text(downloadError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let error = modelManager.downloadErrors[welcomeModel], !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            smartPasteInstructions
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var modelDownloadProgress: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Downloading Base Model")
                        .font(.headline)
                    Text("This will take about 30-60 seconds...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            ProgressView()
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 4) {
                Text(fileProgress?.displayText ?? downloadStageText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                if let detailText = fileProgress?.detailText {
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("The Base model (142MB) provides good accuracy with fast performance.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var downloadStageText: String {
        switch downloadStage {
        case .preparing:
            return "Preparing download..."
        case .creatingModelFolder:
            return "Creating model folder..."
        case .checkingExistingModels:
            return "Checking existing models..."
        case .checkingStorageLimit:
            return "Checking storage limit..."
        case .checkingFreeSpace:
            return "Checking free disk space..."
        case .fetchingFileList:
            return "Fetching model file list..."
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
                    .foregroundStyle(.green)
            }
            
            Label {
                Text("Want to use cloud services instead? You can switch to OpenAI or Google Gemini in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var smartPasteInstructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Smart Paste Feature", systemImage: "accessibility")
                .font(.headline)
                .foregroundStyle(.green)
            
            Text("AudioWhisper can automatically paste transcribed text using CGEvent-based automation:")
                .font(.callout)
            
            VStack(alignment: .leading, spacing: 8) {
                InstructionRow(number: 1, text: "Enable 'Smart Paste' in Settings → General")
                InstructionRow(number: 2, text: "Grant Accessibility permission when prompted")
                InstructionRow(number: 3, text: "Transcribed text will automatically paste into the active app")
            }
            
            Text("You can enable this later in Settings if you prefer manual pasting.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

        guard !isDownloadingModel && !isDismissing else {
            return
        }

        downloadError = nil

        let model = welcomeModel

        // Check synchronously before spawning a task — avoids scheduling on the modal run loop
        // when the model is already present, and prevents unnecessary state mutations.
        if WhisperKitStorage.isModelDownloaded(model) {
            completeWelcome()
            return
        }

        isDownloadingModel = true

        // Task.detached runs on the cooperative thread pool — not on @MainActor.
        // This is necessary because WelcomeView is presented via NSApplication.runModal(),
        // which uses NSModalPanelRunLoopMode. Swift Concurrency's @MainActor executor
        // only processes work in the default/event-tracking run loop modes, so a regular
        // Task { } (which inherits @MainActor) will never start inside a modal session.
        let manager = modelManager
        Task.detached(priority: .userInitiated) {
            do {
                try await manager.downloadModel(model)
                await manager.refreshModelStates()
                await MainActor.run {
                    self.isDownloadingModel = false
                    self.completeWelcome()
                }
            } catch {
                await MainActor.run {
                    self.isDownloadingModel = false
                    self.downloadError = error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription
                }
            }
        }
    }

    @State private var isDismissing = false

    @MainActor
    private func completeWelcome() {
        guard !isDismissing else { return }
        isDismissing = true

        // Persist defaults so service-layer code that reads UserDefaults directly is deterministic.
        UserDefaults.standard.set(AppDefaults.defaultTranscriptionProvider.rawValue, forKey: AppDefaults.Keys.transcriptionProvider)
        UserDefaults.standard.set(AppDefaults.defaultWhisperModel.rawValue, forKey: AppDefaults.Keys.selectedWhisperModel)
        UserDefaults.standard.set(true, forKey: AppDefaults.Keys.hasCompletedWelcome)
        UserDefaults.standard.set(AppDefaults.currentWelcomeVersion, forKey: AppDefaults.Keys.lastWelcomeVersion)

        // Signal completion. WelcomeWindow closes the NSWindow and resumes the async caller.
        onComplete(true)
    }
}

internal struct FeatureRow: View {
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
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.monochrome)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 50) // Ensure consistent height
    }
}

internal struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(.orange)
                .frame(width: 20, alignment: .trailing)
            
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
