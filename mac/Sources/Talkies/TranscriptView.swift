import SwiftUI

struct TranscriptView: View {
    @EnvironmentObject var transcriptionService: TranscriptionService
    @State private var searchText = ""
    @State private var showingSavePanel = false
    @State private var selectedExportFormat: ExportFormat = .vtt
    
    private var filteredSegments: [TranscriptSegment] {
        if searchText.isEmpty {
            return transcriptionService.segments
        } else {
            return transcriptionService.segments.filter { segment in
                segment.text.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Transcript")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("\(transcriptionService.segments.count) segments • \(transcriptionService.totalWords) words")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Search
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search transcript...", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .frame(width: 250)
                        
                        // Export Button
                        Button("Export") {
                            showingSavePanel = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(transcriptionService.segments.isEmpty)
                        
                        // Clear Button
                        Button("Clear") {
                            transcriptionService.clearTranscript()
                        }
                        .buttonStyle(.bordered)
                        .disabled(transcriptionService.segments.isEmpty)
                    }
                }
                
                // Statistics Bar
                if !transcriptionService.segments.isEmpty {
                    StatisticsView()
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 20)
            
            Divider()
            
            // Transcript Content
            ScrollView {
                LazyVStack(spacing: 16) {
                    if filteredSegments.isEmpty {
                        if searchText.isEmpty {
                            EmptyTranscriptView()
                        } else {
                            NoResultsView(searchText: searchText)
                        }
                    } else {
                        ForEach(filteredSegments) { segment in
                            TranscriptSegmentView(segment: segment)
                                .id(segment.id)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .sheet(isPresented: $showingSavePanel) {
            ExportSheet(
                isPresented: $showingSavePanel,
                selectedFormat: $selectedExportFormat,
                transcriptionService: transcriptionService
            )
        }
    }
}

struct StatisticsView: View {
    @EnvironmentObject var transcriptionService: TranscriptionService
    
    var body: some View {
        HStack(spacing: 24) {
            StatItem(
                title: "Duration",
                value: formatDuration(transcriptionService.segments.last?.end ?? 0),
                icon: "clock"
            )
            
            StatItem(
                title: "Words",
                value: "\(transcriptionService.totalWords)",
                icon: "doc.text"
            )
            
            StatItem(
                title: "WPM",
                value: "\(transcriptionService.wordsPerMinute)",
                icon: "speedometer"
            )
            
            StatItem(
                title: "Segments",
                value: "\(transcriptionService.segments.count)",
                icon: "list.bullet"
            )
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private func formatDuration(_ time: Double) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

struct EmptyTranscriptView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Transcript Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Start a recording to see your transcript here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

struct NoResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("No matches for \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

struct ExportSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedFormat: ExportFormat
    @ObservedObject var transcriptionService: TranscriptionService
    @State private var fileName = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Export Transcript")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Format")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    ForEach([ExportFormat.vtt, .srt, .txt], id: \.self) { format in
                        HStack {
                            Button(action: { selectedFormat = format }) {
                                HStack {
                                    Image(systemName: selectedFormat == format ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedFormat == format ? .accentColor : .secondary)
                                    
                                    Text(formatName(for: format))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(formatDescription(for: format))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("File Name")
                    .font(.headline)
                
                TextField("talkies_transcript", text: $fileName)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Export") {
                    exportTranscript()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(fileName.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 400)
        .onAppear {
            fileName = "talkies_\(Date().timeIntervalSince1970)"
        }
    }
    
    private func formatName(for format: ExportFormat) -> String {
        switch format {
        case .vtt: return "WebVTT"
        case .srt: return "SubRip"
        case .txt: return "Plain Text"
        }
    }
    
    private func formatDescription(for format: ExportFormat) -> String {
        switch format {
        case .vtt: return "Web video text tracks"
        case .srt: return "Subtitle format"
        case .txt: return "Simple text file"
        }
    }
    
    private func exportTranscript() {
        let content: String
        let fileExtension: String
        
        switch selectedFormat {
        case .vtt:
            content = transcriptionService.exportVTT()
            fileExtension = "vtt"
        case .srt:
            content = transcriptionService.exportSRT()
            fileExtension = "srt"
        case .txt:
            content = transcriptionService.exportTXT()
            fileExtension = "txt"
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(fileName).\(fileExtension)"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

struct TranscriptView_Previews: PreviewProvider {
    static var previews: some View {
        TranscriptView()
            .environmentObject(TranscriptionService())
            .frame(width: 1200, height: 800)
    }
}