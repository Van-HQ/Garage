import SwiftUI
import PhotosUI
import GarageCore

/// Picks which vehicle the entry is for.
struct VehicleMenu: View {
    @Environment(GarageStore.self) private var store
    let draft: LogDraft

    var body: some View {
        Menu {
            ForEach(store.vehicles) { vehicle in
                Button(vehicle.name) { draft.select(vehicle: vehicle.id, store: store) }
            }
        } label: {
            Text(draft.vehicle(in: store)?.name ?? "Vehicle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.foreground)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Theme.elevated, in: Capsule())
        }
    }
}

struct ChoiceChip: View {
    let title: String
    let selected: Bool
    var fills = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? Theme.accentForeground : Theme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 16)
                .frame(maxWidth: fills ? .infinity : nil, minHeight: 44)
                .background(selected ? Theme.accent : Theme.elevated, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.hairline))
        }
        .buttonStyle(.plain)
    }
}

/// The last seven days as buttons, plus a picker for anything older.
struct DayStrip: View {
    @Binding var date: Date

    var body: some View {
        let calendar = Calendar.current
        let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: Date()) }
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    let selected = calendar.isDate(day, inSameDayAs: date)
                    Button { date = day } label: {
                        VStack(spacing: 8) {
                            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.muted)
                            Text(day.formatted(.dateTime.day()))
                                .font(.system(size: 16, weight: selected ? .bold : .medium))
                                .foregroundStyle(selected ? Theme.accentForeground : Theme.foreground)
                                .frame(width: 40, height: 40)
                                .background(selected ? Theme.accent : Color.clear, in: Circle())
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            DatePicker("Another date", selection: $date, in: ...Date(), displayedComponents: .date)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
    }
}

struct PhotoRow: View {
    let draft: LogDraft
    @Binding var pickedItems: [PhotosPickerItem]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickedItems, maxSelectionCount: 8, matching: .images) {
                    Image(systemName: "camera")
                        .font(.title3)
                        .foregroundStyle(Theme.muted)
                        .frame(width: 72, height: 72)
                        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityLabel("Add photos")
                ForEach(draft.photos) { photo in
                    Image(uiImage: photo.thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Button { draft.photos.removeAll { $0.id == photo.id } } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: -6)
                            .accessibilityLabel("Remove photo")
                        }
                }
            }
            .padding(.vertical, 6)
            .padding(.trailing, 6)
        }
        .scrollIndicators(.hidden)
    }
}
