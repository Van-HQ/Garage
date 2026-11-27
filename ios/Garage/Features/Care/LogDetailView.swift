import SwiftUI
import GarageCore

/// A logged service with its notes and photos. It can be deleted here; editing lives on the web.
struct LogDetailView: View {
    @Environment(GarageStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let log: MaintenanceLog

    @State private var photoURLs: [String: URL] = [:]
    @State private var confirmingDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        let photos = store.photos(for: log)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Panel(padding: 0) {
                        VStack(spacing: 0) {
                            row("Date", log.performedAt.mediumDay)
                            Divider().overlay(Theme.hairline)
                            row("Odometer", "\(log.mileageAt.grouped) mi")
                            if let cost = log.cost {
                                Divider().overlay(Theme.hairline)
                                row("Cost", cost.formatted(.currency(code: "USD")))
                            }
                            if let vehicle = store.vehicles.first(where: { $0.id == log.vehicleID }) {
                                Divider().overlay(Theme.hairline)
                                row("Vehicle", vehicle.name)
                            }
                        }
                    }

                    if let notes = log.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Notes")
                            Panel {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.foreground)
                            }
                        }
                    }

                    if !photos.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Photos")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                                ForEach(photos) { photo in
                                    photoTile(photoURLs[photo.storagePath])
                                }
                            }
                        }
                    }

                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Panel(padding: 16) {
                            Group {
                                if isDeleting { ProgressView() } else { Text("Delete entry").font(.system(size: 16, weight: .medium)) }
                            }
                            .foregroundStyle(Theme.statusOverdue)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)

                    if let deleteError {
                        Text(deleteError).font(.footnote).foregroundStyle(Theme.statusOverdue)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(log.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete \(log.title)", role: .destructive, action: delete)
            } message: {
                Text("\(log.performedAt.mediumDay) · \(log.mileageAt.grouped) mi. Its photos go too. This can't be undone.")
            }
            .task(id: photos.map(\.storagePath)) {
                guard !photos.isEmpty else { return }
                photoURLs = (try? await store.backend.photoURLs(for: photos.map(\.storagePath))) ?? [:]
            }
        }
    }

    private func delete() {
        isDeleting = true
        deleteError = nil
        Task {
            do {
                try await store.delete(log)
                dismiss()
            } catch {
                deleteError = error.localizedDescription
                isDeleting = false
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).foregroundStyle(Theme.foreground).monospacedDigit()
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func photoTile(_ url: URL?) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: Image(systemName: "photo").foregroundStyle(Theme.muted)
                    default: ProgressView()
                    }
                }
            }
            .background(Theme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
