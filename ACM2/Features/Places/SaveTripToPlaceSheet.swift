import SwiftUI

/// Bottom sheet shown after a trip is saved, letting the user assign it to a place.
struct SaveTripToPlaceSheet: View {

    let tripId:  UUID
    @Binding var isPresented: Bool

    @EnvironmentObject var placesStore: SavedPlacesStore

    @State private var selectedPlaceId: UUID?
    @State private var showNewPlace     = false
    @State private var newPlaceName     = ""
    @State private var newPlaceCategory: PlaceCategory = .other

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title).foregroundStyle(.blue)
                    Text("Where did you go?")
                        .font(.title3.bold())
                    Text("Assign this trip to a place to track patterns and reminders.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 20).padding(.bottom, 16)

                Divider()

                ScrollView {
                    VStack(spacing: 10) {
                        // Existing places
                        ForEach(placesStore.places) { place in
                            placeRow(place)
                        }

                        // Add new place button
                        if !showNewPlace {
                            Button {
                                withAnimation { showNewPlace = true }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(Color.gray.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3).foregroundStyle(.blue)
                                    }
                                    Text("Add New Place")
                                        .font(.subheadline).foregroundStyle(.blue)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 8)
                            }
                        } else {
                            newPlaceForm
                        }
                    }
                    .padding(.vertical, 12)
                }

                Divider()

                // Action buttons
                HStack(spacing: 12) {
                    Button("Skip") {
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        if let id = selectedPlaceId {
                            placesStore.assignTrip(tripId: tripId, toPlace: id)
                        }
                        isPresented = false
                    } label: {
                        Text(selectedPlaceId != nil ? "Save to Place" : "Skip")
                            .font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedPlaceId != nil ? Color.blue : Color.gray.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(selectedPlaceId == nil)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { isPresented = false }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Place Row

    private func placeRow(_ place: SavedPlace) -> some View {
        let isSelected = selectedPlaceId == place.id
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                selectedPlaceId = isSelected ? nil : place.id
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? place.category.color : place.category.color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: place.category.icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : place.category.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(place.displayName).font(.subheadline.bold())
                    Text("\(place.tripCount) trip\(place.tripCount == 1 ? "" : "s") saved")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue).font(.title3)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(isSelected ? Color.blue.opacity(0.07) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    // MARK: - New Place Form

    private var newPlaceForm: some View {
        VStack(spacing: 10) {
            HStack {
                Text("New Place").font(.subheadline.bold())
                Spacer()
                Button {
                    withAnimation { showNewPlace = false }
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)

            TextField("Place name (e.g. Gym, Airport…)", text: $newPlaceName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)

            // Category picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlaceCategory.allCases) { cat in
                        Button {
                            newPlaceCategory = cat
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: cat.icon).font(.caption)
                                Text(cat.label).font(.caption.bold())
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(newPlaceCategory == cat ? cat.color : cat.color.opacity(0.1))
                            .foregroundStyle(newPlaceCategory == cat ? .white : cat.color)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            Button {
                let trimmed = newPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                var place = SavedPlace(name: trimmed, category: newPlaceCategory)
                place.customLabel = trimmed
                placesStore.add(place)
                selectedPlaceId = place.id
                withAnimation { showNewPlace = false }
            } label: {
                Text("Create & Select")
                    .font(.subheadline.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(newPlaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.gray : Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(newPlaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 8)
    }
}
