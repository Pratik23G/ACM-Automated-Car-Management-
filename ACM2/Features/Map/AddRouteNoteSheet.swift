import SwiftUI
import CoreLocation

struct AddRouteNoteSheet: View {

    let tripId:     UUID
    let coordinate: SerializableCoordinate  // current GPS position
    let onSave:     (RouteNote) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var noteType:         RouteNote.NoteType = .general
    @State private var title:            String = ""
    @State private var noteBody:             String = ""
    @State private var isReminder:       Bool   = false
    @State private var reminderMessage:  String = ""

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Type Picker
                Section("What are you recording?") {
                    Picker("Type", selection: $noteType) {
                        ForEach(RouteNote.NoteType.allCases) { type in
                            Label(type.label, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 130)
                }

                // MARK: Content
                Section("Details") {
                    TextField("Title (e.g. Great lake view, Speed trap)", text: $title)
                    TextField("Additional notes (optional)", text: $noteBody, axis: .vertical)
                        .lineLimit(3...6)
                }

                // MARK: Reminder Toggle
                Section {
                    Toggle("Set as Route Reminder", isOn: $isReminder.animation())

                    if isReminder {
                        TextField("Reminder message (what the app should say when you approach this spot)",
                                  text: $reminderMessage, axis: .vertical)
                            .lineLimit(2...4)
                    }
                } footer: {
                    if isReminder {
                        Text("ACM will alert you \(Int(350)) m before you reach this spot on any future trip through this area.")
                            .font(.caption)
                    }
                }

                // MARK: Location info
                Section("Location Pinned") {
                    HStack {
                        Image(systemName: "location.fill").foregroundStyle(.blue)
                        Text(String(format: "%.5f, %.5f",
                                    coordinate.latitude, coordinate.longitude))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Record Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let note = RouteNote(
            tripId:          tripId,
            coordinate:      coordinate,
            type:            noteType,
            title:           title.trimmingCharacters(in: .whitespacesAndNewlines),
            body:            noteBody.trimmingCharacters(in: .whitespacesAndNewlines),
            isReminder:      isReminder,
            reminderMessage: isReminder ? reminderMessage : nil
        )
        onSave(note)
        dismiss()
    }
}

