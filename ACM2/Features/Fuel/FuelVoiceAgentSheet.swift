import SwiftUI

struct FuelVoiceAgentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let prompts: [String]
    let onChoosePrompt: (String) -> Void

    @State private var isVoiceBridgeArmed = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice Fuel Agent")
                        .font(.title2.bold())
                    Text("This is the handoff point for Vapi. Right now it stages questions into the same fuel-intelligence pipeline the text box uses, so your teammate can replace this with the live voice session later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isVoiceBridgeArmed.toggle()
                } label: {
                    Label(
                        isVoiceBridgeArmed ? "Voice Agent Ready" : "Start Voice Agent",
                        systemImage: isVoiceBridgeArmed ? "waveform.circle.fill" : "mic.circle.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)

                Text(isVoiceBridgeArmed
                    ? "Use one of the sample prompts below to simulate what the live Vapi handoff will ask."
                    : "Tap the button above to stage the voice bridge, then pass one of these prompts into the text flow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Suggested voice prompts")
                        .font(.subheadline.bold())

                    ForEach(prompts, id: \.self) { prompt in
                        Button {
                            onChoosePrompt(prompt)
                            dismiss()
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mic.fill")
                                    .foregroundStyle(.blue)
                                Text(prompt)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Voice Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
