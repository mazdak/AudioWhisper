import SwiftUI
import AppKit

internal struct TranscriptionRecordRow: View {
    let record: TranscriptionRecord
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var hoveredButton: String? = nil
    
    var body: some View {
        Button(action: onToggleExpand) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                .animation(.easeInOut(duration: 0.2), value: isExpanded)
                                .frame(width: 12)
                            
                            Text(record.formattedDate)
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            HStack(spacing: 8) {
                                providerBadge
                                
                                if let duration = record.formattedDuration {
                                    HStack(spacing: 3) {
                                        Image(systemName: "clock")
                                            .font(.caption2)
                                        Text(duration)
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                                
                                if let modelUsed = record.modelUsed {
                                    Text(modelUsed)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Button(action: { onCopy() }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                        .foregroundStyle(hoveredButton == "copy" ? .blue : .secondary)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(hoveredButton == "copy" ? Color.blue.opacity(0.1) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help("Copy to clipboard")
                                .onHover { isHovering in
                                    hoveredButton = isHovering ? "copy" : nil
                                }
                                
                                Button(action: { onDelete() }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(hoveredButton == "delete" ? .red : .secondary)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(hoveredButton == "delete" ? Color.red.opacity(0.1) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help("Delete")
                                .onHover { isHovering in
                                    hoveredButton = isHovering ? "delete" : nil
                                }
                            }
                            .opacity(isHovered ? 1 : 0)
                            .animation(.easeInOut(duration: 0.15), value: isHovered)
                        }
                        
                        Text(record.text)
                            .font(.body)
                            .foregroundStyle(isExpanded ? .primary : .secondary)
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animation(nil, value: isExpanded)
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 16)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(.plain)
        .background(
            Rectangle()
                .fill(backgroundFill)
        )
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Transcription from \(record.formattedDate), using \(record.provider)")
        .accessibilityHint("Tap to expand or collapse. Use action buttons to copy or delete.")
    }
    
    @ViewBuilder
    private var providerBadge: some View {
        if let provider = record.transcriptionProvider {
            Text(provider.displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(providerColor(for: provider))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            Text(record.provider)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
    
    private var backgroundFill: Color {
        isHovered ? Color(NSColor.controlBackgroundColor) : Color.clear
    }
    
    private func providerColor(for provider: TranscriptionProvider) -> Color {
        switch provider {
        case .openai:
            return .green
        case .gemini:
            return .blue
        case .local:
            return .purple
        case .parakeet:
            return .orange
        }
    }
}
