import SwiftUI

/// Streamlined record sheet — user picks a type (required) and an optional
/// one-line title. Full notes can be added later in the route detail view.
struct QuickRecordSheet: View {

    let tripId:     UUID
    let coordinate: SerializableCoordinate
    let onSave:     (RouteNote) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var noteType:        RouteNote.NoteType = .general
    @State private var title:           String = ""
    @State private var isReminder:      Bool   = false
    @State private var reminderMessage: String = ""

    // Type options laid out as a quick-tap grid
    private let types = RouteNote.NoteType.allCases

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: Type Grid
                VStack(alignment: .leading, spacing: 10) {
                    Text("What are you recording?")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                              spacing: 10) {
                        ForEach(types) { type in
                            typeButton(type)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)

                Divider().padding(.vertical, 16)

                // MARK: Optional Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick label (optional)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    TextField("e.g. Speed trap, Great view, Pothole", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                // MARK: Reminder toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Set as Reminder", isOn: $isReminder.animation())
                        .padding(.top, 16)

                    if isReminder {
                        TextField("Message when you pass this spot…",
                                  text: $reminderMessage, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...3)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // MARK: Save button
                Button(action: save) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Drop Pin")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(noteType.color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Record Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Type Button

    private func typeButton(_ type: RouteNote.NoteType) -> some View {
        let selected = noteType == type
        return Button { noteType = type } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selected ? type.color : type.color.opacity(0.12))
                        .frame(height: 54)
                    Image(systemName: type.icon)
                        .font(.title3)
                        .foregroundStyle(selected ? .white : type.color)
                }
                Text(type.label)
                    .font(.caption.bold())
                    .foregroundStyle(selected ? type.color : .secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? type.color : .clear, lineWidth: 2)
        )
        .animation(.spring(duration: 0.2), value: selected)
    }

    // MARK: - Save

    private func save() {
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? noteType.label    // default to type name if no title entered
            : title.trimmingCharacters(in: .whitespacesAndNewlines)

        let note = RouteNote(
            tripId:          tripId,
            coordinate:      coordinate,
            type:            noteType,
            title:           finalTitle,
            body:            "",
            isReminder:      isReminder,
            reminderMessage: isReminder ? reminderMessage : nil
        )
        onSave(note)
        dismiss()
    }
}

