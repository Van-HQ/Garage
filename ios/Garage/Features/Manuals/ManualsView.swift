import SwiftUI
import PDFKit
import GarageCore

/// Owner's manuals: one PDF per vehicle, stored in the private `manuals` bucket.
struct ManualsView: View {
    @Environment(GarageStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if store.vehicles.isEmpty {
                        EmptyPanel(message: "Add a vehicle in the web app's Settings first.")
                    } else {
                        ListPanel(items: store.vehicles) { vehicle in
                            if vehicle.manualUploadedAt != nil {
                                NavigationLink(value: vehicle) { row(vehicle) }
                                    .buttonStyle(.plain)
                            } else {
                                row(vehicle)
                            }
                        }
                        Text("Upload or replace a manual from the web app's Settings.")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Theme.background)
            .navigationTitle("Manuals")
            .navigationDestination(for: Vehicle.self) { ManualReaderView(vehicle: $0) }
            .refreshable { await store.refresh() }
        }
    }

    private func row(_ vehicle: Vehicle) -> some View {
        let hasManual = vehicle.manualUploadedAt != nil
        return HStack(spacing: 10) {
            IconTile(systemName: "book.closed", color: hasManual ? Theme.accent : Theme.muted)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "\(vehicle.year) \(vehicle.make) \(vehicle.name)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(1)
                Text(vehicle.manualUploadedAt.map { "Owner's manual · added \($0.mediumDay)" } ?? "No manual uploaded")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if hasManual {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Downloads the manual through a signed URL and shows it, with zoom buttons and search.
/// The file is kept in the caches folder, so reopening the same manual doesn't download it again.
struct ManualReaderView: View {
    @Environment(GarageStore.self) private var store
    let vehicle: Vehicle

    @StateObject private var controller = ManualController()
    @State private var hasDocument = false
    @State private var errorMessage: String?
    @State private var showSearch = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        Group {
            if hasDocument {
                VStack(spacing: 0) {
                    if showSearch { searchBar }
                    PDFKitView(controller: controller)
                        .ignoresSafeArea(edges: .bottom)
                }
            } else if let errorMessage {
                ContentUnavailableView("Couldn't open the manual", systemImage: "book.closed", description: Text(errorMessage))
            } else {
                ProgressView("Loading manual…")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("\(vehicle.name) manual")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasDocument {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { controller.zoomOut() } label: { Image(systemName: "minus.magnifyingglass") }
                        .accessibilityLabel("Zoom out")
                    Button { controller.zoomIn() } label: { Image(systemName: "plus.magnifyingglass") }
                        .accessibilityLabel("Zoom in")
                    Button {
                        showSearch.toggle()
                        if showSearch { searchFocused = true } else { controller.clearSearch() }
                    } label: { Image(systemName: "magnifyingglass") }
                        .accessibilityLabel("Search")
                }
            }
        }
        .task { await load() }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("Search this manual", text: $controller.query)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { controller.next() }
                    .onChange(of: controller.query) { _, text in controller.search(text) }
                if !controller.query.isEmpty {
                    Button { controller.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted) }
                        .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Theme.elevated, in: Capsule())

            if controller.isSearching {
                ProgressView().controlSize(.small)
            } else if controller.query.count >= 2 {
                Text(controller.matchCount == 0 ? "None" : "\(controller.currentIndex + 1) of \(controller.matchCount)\(controller.matchesCapped ? "+" : "")")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
            }
            Button { controller.previous() } label: { Image(systemName: "chevron.up") }
                .disabled(controller.matchCount == 0)
                .accessibilityLabel("Previous match")
            Button { controller.next() } label: { Image(systemName: "chevron.down") }
                .disabled(controller.matchCount == 0)
                .accessibilityLabel("Next match")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.background)
    }

    private func load() async {
        guard !hasDocument else { return }
        do {
            let file = try await ManualCache.file(for: vehicle, backend: store.backend)
            guard let loaded = PDFDocument(url: file) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            controller.setDocument(loaded)
            hasDocument = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Owns the PDF view so the zoom buttons and the search can drive it.
@MainActor
final class ManualController: NSObject, ObservableObject, PDFDocumentDelegate {
    let pdfView = PDFView()

    @Published var query = ""
    @Published private(set) var matchCount = 0
    @Published private(set) var currentIndex = 0
    @Published private(set) var isSearching = false
    @Published private(set) var matchesCapped = false

    /// Once the zoom buttons are used, stop re-fitting the page to the screen.
    private(set) var hasZoomed = false
    private var matches: [PDFSelection] = []
    /// Stop collecting after this many, so a very common word can't bog the phone down.
    private static let maxMatches = 500

    override init() {
        super.init()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.maxScaleFactor = 6
        pdfView.backgroundColor = UIColor(Theme.background)
    }

    func setDocument(_ document: PDFDocument) {
        document.delegate = self
        pdfView.document = document
    }

    // MARK: Zoom

    func zoomIn() { zoom(by: 1.25) }
    func zoomOut() { zoom(by: 0.8) }

    private func zoom(by factor: CGFloat) {
        hasZoomed = true
        pdfView.autoScales = false
        let fit = pdfView.scaleFactorForSizeToFit
        let target = pdfView.scaleFactor * factor
        pdfView.scaleFactor = min(max(target, fit * 0.5), pdfView.maxScaleFactor)
    }

    // MARK: Search

    func search(_ text: String) {
        pdfView.document?.cancelFindString()
        matches = []
        matchCount = 0
        currentIndex = 0
        matchesCapped = false
        pdfView.highlightedSelections = nil
        pdfView.clearSelection()

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, let document = pdfView.document else {
            isSearching = false
            return
        }
        isSearching = true
        document.beginFindString(trimmed, withOptions: .caseInsensitive)
    }

    func clearSearch() {
        query = ""
        search("")
    }

    func next() { step(1) }
    func previous() { step(-1) }

    private func step(_ delta: Int) {
        guard !matches.isEmpty else { return }
        currentIndex = (currentIndex + delta + matches.count) % matches.count
        show(currentIndex)
    }

    private func show(_ index: Int) {
        let match = matches[index]
        pdfView.setCurrentSelection(match, animate: true)
        pdfView.go(to: match)
    }

    nonisolated func didMatchString(_ instance: PDFSelection) {
        Task { @MainActor in
            guard self.matches.count < Self.maxMatches else { return }
            instance.color = UIColor.systemYellow.withAlphaComponent(0.55)
            self.matches.append(instance)
            self.matchCount = self.matches.count
            self.pdfView.highlightedSelections = self.matches
            if self.matches.count == 1 { self.show(0) }
            if self.matches.count >= Self.maxMatches {
                self.matchesCapped = true
                self.pdfView.document?.cancelFindString()
                self.isSearching = false
            }
        }
    }

    nonisolated func documentDidEndDocumentFind(_ notification: Notification) {
        Task { @MainActor in self.isSearching = false }
    }
}

enum ManualCache {
    /// The cached PDF for this vehicle, downloading it first if needed. The file
    /// name includes the upload time, so a replaced manual is fetched again.
    static func file(for vehicle: Vehicle, backend: GarageBackend) async throws -> URL {
        guard let uploadedAt = vehicle.manualUploadedAt else { throw BackendError.noManual }
        let folder = try FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("manuals", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let prefix = vehicle.id.uuidString.lowercased()
        let target = folder.appendingPathComponent("\(prefix)-\(Int(uploadedAt.timeIntervalSince1970)).pdf")
        if FileManager.default.fileExists(atPath: target.path) { return target }

        let signedURL = try await backend.manualURL(for: vehicle)
        let downloaded: URL
        if signedURL.isFileURL {
            downloaded = signedURL // demo mode hands over a local file
        } else {
            let (file, response) = try await URLSession.shared.download(from: signedURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            downloaded = file
        }

        // Drop older copies of this vehicle's manual before keeping the new one.
        let stale = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for url in stale where url.lastPathComponent.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: url)
        }
        if signedURL.isFileURL { try FileManager.default.copyItem(at: downloaded, to: target) }
        else { try FileManager.default.moveItem(at: downloaded, to: target) }
        return target
    }
}

private struct PDFKitView: UIViewRepresentable {
    let controller: ManualController

    func makeUIView(context: Context) -> PDFView { controller.pdfView }
    func updateUIView(_ view: PDFView, context: Context) {
        // The view was built before it had a size, so ask for the fit-to-width scale again now.
        if !controller.hasZoomed { view.autoScales = true }
    }
}
