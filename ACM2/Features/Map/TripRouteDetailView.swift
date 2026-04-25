import SwiftUI
import MapKit

struct TripRouteDetailView: View {

    let route: TripRoute

    @EnvironmentObject var routeStore: RouteStore

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedNote: RouteNote?

    // Post-trip note adding
    @State private var isAddingNote     = false
    @State private var pendingCoord:     SerializableCoordinate?
    @State private var showAddNoteSheet  = false
    @State private var showAddNoteTip    = false

    var body: some View {
        ZStack(alignment: .bottom) {
            mapReader
            if let note = selectedNote {
                noteDetailCard(note)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding()
            }
            if isAddingNote {
                addNoteInstructions
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle("Trip Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { addNoteToolbar }
        .sheet(isPresented: $showAddNoteSheet) {
            if let coord = pendingCoord {
                AddRouteNoteSheet(tripId: route.id, coordinate: coord) { note in
                    routeStore.addNote(note)
                    pendingCoord = nil
                }
            }
        }
        .onAppear { fitCamera() }
        .animation(.spring(duration: 0.3), value: selectedNote?.id)
        .animation(.spring(duration: 0.25), value: isAddingNote)
    }

    // MARK: - Map with tap-to-place

    private var mapReader: some View {
        MapReader { proxy in
            Map(position: $position) {
                // Blue route line
                if route.coordinates.count > 1 {
                    MapPolyline(coordinates: route.coordinates.map { $0.clCoordinate })
                        .stroke(.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round,
                                                           lineJoin: .round))
                }
                // Start / end markers
                if let first = route.coordinates.first {
                    Annotation("Start", coordinate: first.clCoordinate) {
                        Circle().fill(.green).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 2)).shadow(radius: 3)
                    }
                }
                if let last = route.coordinates.last, route.coordinates.count > 1 {
                    Annotation("End", coordinate: last.clCoordinate) {
                        Circle().fill(.red).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 2)).shadow(radius: 3)
                    }
                }
                // Pending pin
                if let pending = pendingCoord {
                    Annotation("New Note", coordinate: pending.clCoordinate) {
                        ZStack {
                            Circle().fill(Color.accentColor).frame(width: 36, height: 36)
                                .shadow(radius: 5)
                            Image(systemName: "plus").foregroundStyle(.white).font(.title3.bold())
                        }
                    }
                }
                // Existing note markers
                ForEach(updatedNotes) { note in
                    Annotation(note.title, coordinate: note.coordinate.clCoordinate) {
                        Button {
                            withAnimation { selectedNote = (selectedNote?.id == note.id) ? nil : note }
                        } label: {
                            ZStack {
                                Circle().fill(note.type.color).frame(width: 36, height: 36)
                                    .shadow(radius: 4)
                                Image(systemName: note.type.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .overlay(
                                note.isReminder ?
                                Circle().stroke(Color.purple.opacity(0.5), lineWidth: 3)
                                    .frame(width: 48, height: 48) : nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard)
            .mapControls { MapUserLocationButton(); MapCompass(); MapScaleView() }
            .ignoresSafeArea(edges: .top)
            .onTapGesture { position in
                if isAddingNote, let coord = proxy.convert(position, from: .local) {
                    pendingCoord = SerializableCoordinate(coord)
                    showAddNoteSheet = true
                    isAddingNote = false
                    withAnimation { selectedNote = nil }
                } else {
                    withAnimation { selectedNote = nil }
                }
            }
        }
    }

    // Latest notes from the store (so added notes show immediately)
    private var updatedNotes: [RouteNote] {
        routeStore.route(for: route.id)?.notes ?? route.notes
    }

    // MARK: - Add Note instructions overlay

    private var addNoteInstructions: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill").foregroundStyle(.white)
            Text("Tap anywhere on the map to place a note")
                .font(.subheadline.bold()).foregroundStyle(.white)
            Spacer()
            Button { isAddingNote = false; pendingCoord = nil } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(radius: 8)
        .padding(.horizontal, 14).padding(.top, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Add Note toolbar

    private var addNoteToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                pendingCoord = nil
                withAnimation { isAddingNote.toggle(); selectedNote = nil }
            } label: {
                Label(isAddingNote ? "Cancel" : "Add Note",
                      systemImage: isAddingNote ? "xmark" : "plus.circle.fill")
                    .foregroundStyle(isAddingNote ? .red : .accentColor)
            }
        }
    }

    // MARK: - Note Detail Card

    private func noteDetailCard(_ note: RouteNote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(note.type.color.opacity(0.15))
                    Image(systemName: note.type.icon).foregroundStyle(note.type.color).font(.title3)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title).font(.headline)
                    Text(note.type.label).font(.caption).foregroundStyle(note.type.color)
                }
                Spacer()
                Button { withAnimation { selectedNote = nil } } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.title3)
                }
                .buttonStyle(.plain)
            }

            if !note.body.isEmpty {
                Text(note.body).font(.subheadline).foregroundStyle(.secondary)
            }

            if note.isReminder, let msg = note.reminderMessage, !msg.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill").foregroundStyle(.purple).font(.caption)
                    Text("Reminder: \(msg)").font(.caption).foregroundStyle(.purple)
                }
                .padding(8).background(Color.purple.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2).foregroundStyle(.secondary)

            Button(role: .destructive) {
                routeStore.deleteNote(id: note.id, fromTripId: route.id)
                withAnimation { selectedNote = nil }
            } label: {
                Label("Delete Note", systemImage: "trash").font(.footnote).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(radius: 10)
    }

    // MARK: - Camera

    private func fitCamera() {
        guard let bounds = route.boundingRegion else { return }
        position = .region(MKCoordinateRegion(
            center: bounds.center.clCoordinate,
            span: MKCoordinateSpan(latitudeDelta: bounds.latDelta,
                                   longitudeDelta: bounds.lngDelta)))
    }
}

