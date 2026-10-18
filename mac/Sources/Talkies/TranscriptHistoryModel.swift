import Foundation
import Combine
import TalkiesCore

/// UI state for the persistent transcript history. Database work runs on the
/// `TranscriptHistoryStore` actor; this type only publishes results on the main actor.
/// Error messages shown or logged here never include transcript text.
@MainActor
final class TranscriptHistoryModel: ObservableObject {
    static let shared = TranscriptHistoryModel(store: TranscriptHistoryStore.defaultFileURL().map(TranscriptHistoryStore.init(fileURL:)))

    static let pageSize = 50

    @Published private(set) var entries: [TranscriptRecord] = []
    @Published private(set) var hasMore = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var searchText = "" {
        didSet { if searchText != oldValue { scheduleReload() } }
    }

    private let store: TranscriptHistoryStore?
    private var loadGeneration = 0
    private var searchDebounce: Task<Void, Never>?

    init(store: TranscriptHistoryStore?) {
        self.store = store
    }

    /// Reloads the first page for the current search.
    func reload() {
        searchDebounce?.cancel()
        loadPage(appending: false)
    }

    func loadMore() {
        guard hasMore, !isLoading else { return }
        loadPage(appending: true)
    }

    func save(_ transcript: NewTranscript) {
        guard let store else { return }
        Task {
            do {
                try await store.insert(transcript)
                self.reload()
            } catch {
                self.report("save", error)
            }
        }
    }

    func delete(_ entry: TranscriptRecord) {
        guard let store else { return }
        entries.removeAll { $0.id == entry.id }
        Task {
            do { try await store.delete(id: entry.id) }
            catch {
                self.report("delete", error)
                self.reload()
            }
        }
    }

    func clearAll() {
        guard let store else { return }
        loadGeneration += 1
        entries = []
        hasMore = false
        Task {
            do { try await store.clearAll() }
            catch { self.report("clear", error) }
            self.reload()
        }
    }

    private func scheduleReload() {
        searchDebounce?.cancel()
        searchDebounce = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.loadPage(appending: false)
        }
    }

    private func loadPage(appending: Bool) {
        guard let store else {
            errorMessage = "Transcript history is unavailable."
            return
        }
        loadGeneration += 1
        let generation = loadGeneration
        let search = searchText
        let after = appending ? entries.last : nil
        isLoading = true
        Task {
            do {
                let page = try await store.fetch(search: search, limit: Self.pageSize, after: after)
                guard generation == self.loadGeneration else { return }
                self.entries = appending ? self.entries + page : page
                self.hasMore = page.count == Self.pageSize
                self.errorMessage = nil
            } catch {
                guard generation == self.loadGeneration else { return }
                self.report("load", error)
            }
            self.isLoading = false
        }
    }

    private func report(_ operation: String, _ error: Error) {
        errorMessage = error.localizedDescription
        print("⚠️ Transcript history \(operation) failed: \(error.localizedDescription)")
    }
}
