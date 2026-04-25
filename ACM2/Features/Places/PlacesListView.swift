import SwiftUI

struct PlacesListView: View {

    @EnvironmentObject var placesStore: SavedPlacesStore
    @EnvironmentObject var tripHistory: TripHistoryStore

    @State private var showAddPlace  = false
    @State private var editingPlace: SavedPlace?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Category grid (Home / Work / School pinned at top)
                    pinnedGrid

                    // All places list
                    if placesStore.places.count > 3 {
                        VStack(spacing: 0) {
                            ForEach(placesStore.places.dropFirst(3)) { place in
                                NavigationLink(destination: SmartPlaceBriefView(place: place)) {
                                    placeRow(place)
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 70)
                            }
                        }
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("My Places")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddPlace = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddPlace) { addPlaceSheet }
            .sheet(item: $editingPlace) { place in editPlaceSheet(place) }
        }
    }

    // MARK: - Pinned Grid (first 3 places)

    private var pinnedGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                  spacing: 12) {
            ForEach(placesStore.places.prefix(3)) { place in
                NavigationLink(destination: SmartPlaceBriefView(place: place)) {
                    pinnedCard(place)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private func pinnedCard(_ place: SavedPlace) -> some View {
        let pattern = place.pattern(from: tripHistory.trips)
        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(place.category.color.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: place.category.icon)
                    .font(.title2).foregroundStyle(place.category.color)
            }
            Text(place.displayName)
                .font(.subheadline.bold()).lineLimit(1)

            if let p = pattern {
                Text(p.avgDurationFormatted)
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("\(place.tripCount) trip\(place.tripCount == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Reminder dot
            if !place.reminders.filter({ $0.isActive }).isEmpty {
                HStack(spacing: 4) {
                    Circle().fill(.blue).frame(width: 5, height: 5)
                    Text("\(place.reminders.filter({ $0.isActive }).count) reminder\(place.reminders.filter({ $0.isActive }).count == 1 ? "" : "s")")
                        .font(.caption2).foregroundStyle(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Place Row

    private func placeRow(_ place: SavedPlace) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(place.category.color.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: place.category.icon)
                    .font(.title3).foregroundStyle(place.category.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(place.displayName).font(.subheadline.bold())
                Text("\(place.tripCount) trip\(place.tripCount == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Add Place Sheet

    @State private var newName     = ""
    @State private var newCategory: PlaceCategory = .other

    private var addPlaceSheet: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Gym, Airport, Friend's House", text: $newName)
                }
                Section("Category") {
                    ForEach(PlaceCategory.allCases) { cat in
                        HStack {
                            Image(systemName: cat.icon).foregroundStyle(cat.color).frame(width: 24)
                            Text(cat.label)
                            Spacer()
                            if newCategory == cat {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { newCategory = cat }
                    }
                }
            }
            .navigationTitle("New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showAddPlace = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        var place = SavedPlace(name: trimmed, category: newCategory)
                        place.customLabel = trimmed
                        placesStore.add(place)
                        newName = ""
                        showAddPlace = false
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.headline)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Edit Place Sheet

    private func editPlaceSheet(_ place: SavedPlace) -> some View {
        EditPlaceView(place: place)
    }
}

// MARK: - EditPlaceView

struct EditPlaceView: View {
    let place: SavedPlace
    @EnvironmentObject var placesStore: SavedPlacesStore
    @Environment(\.dismiss) private var dismiss

    @State private var name:     String
    @State private var category: PlaceCategory

    init(place: SavedPlace) {
        self.place = place
        _name     = State(initialValue: place.customLabel ?? place.name)
        _category = State(initialValue: place.category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Place name", text: $name) }
                Section("Category") {
                    ForEach(PlaceCategory.allCases) { cat in
                        HStack {
                            Image(systemName: cat.icon).foregroundStyle(cat.color).frame(width: 24)
                            Text(cat.label); Spacer()
                            if category == cat { Image(systemName: "checkmark").foregroundStyle(.blue) }
                        }
                        .contentShape(Rectangle()).onTapGesture { category = cat }
                    }
                }
                Section {
                    Button("Delete Place", role: .destructive) {
                        placesStore.delete(id: place.id); dismiss()
                    }
                }
            }
            .navigationTitle("Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var updated = place
                        updated.customLabel = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.category    = category
                        placesStore.update(updated)
                        dismiss()
                    }.font(.headline)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
