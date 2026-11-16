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
                Text("\(vehicle.year) \(vehicle.make) \(vehicle.name)")
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

/// Downloads the manual through a signed URL and shows it. The file is kept in
/// the caches folder, so reopening the same manual doesn't download it again.
struct ManualReaderView: View {
    @Environment(GarageStore.self) private var store
    let vehicle: Vehicle

    @State private var document: PDFDocument?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let document {
                PDFKitView(document: document)
                    .ignoresSafeArea(edges: .bottom)
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
        .task { await load() }
    }

    private func load() async {
        guard document == nil else { return }
        do {
            let file = try await ManualCache.file(for: vehicle, backend: store.backend)
            guard let loaded = PDFDocument(url: file) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            document = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
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
        let (downloaded, response) = try await URLSession.shared.download(from: signedURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // Drop older copies of this vehicle's manual before keeping the new one.
        let stale = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for url in stale where url.lastPathComponent.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: downloaded, to: target)
        return target
    }
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor(Theme.background)
        view.document = document
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
    }
}
