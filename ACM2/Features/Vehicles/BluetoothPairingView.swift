import SwiftUI
import CoreBluetooth

struct BluetoothPairingView: View {

    @Binding var pairedDeviceUUID: String?
    @Binding var pairedDeviceName: String?

    @StateObject private var trigger = BluetoothTripTrigger()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Current pairing status
                Section("Current Pairing") {
                    if let name = pairedDeviceName {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(.subheadline.bold())
                                Text("Paired — ACM will auto-detect drives")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove", role: .destructive) {
                                pairedDeviceUUID = nil
                                pairedDeviceName = nil
                            }
                            .font(.caption)
                        }
                    } else {
                        Label("No device paired", systemImage: "bluetooth")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                // State warnings
                if trigger.state == .poweredOff {
                    Section {
                        Label("Bluetooth is off. Enable it in Settings.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.footnote)
                    }
                } else if trigger.state == .unauthorized {
                    Section {
                        Label("Bluetooth access denied. Update in Settings.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red).font(.footnote)
                    }
                }

                // Scan section
                Section {
                    if trigger.isScanning {
                        HStack {
                            ProgressView().padding(.trailing, 6)
                            Text("Scanning for nearby devices…")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }

                    ForEach(trigger.nearbyDevices) { device in
                        Button { pair(device: device) } label: {
                            HStack {
                                Image(systemName: "wave.3.right.circle.fill")
                                    .foregroundStyle(.blue).font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.displayName).font(.subheadline)
                                    Text(device.signalStrength + " signal")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if pairedDeviceUUID == device.uuid {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else {
                                    Text("Pair").font(.caption.bold()).foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if !trigger.isScanning {
                        Button {
                            trigger.startDiscoveryScan()
                        } label: {
                            Label(trigger.nearbyDevices.isEmpty ? "Scan for Devices" : "Scan Again",
                                  systemImage: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(trigger.state == .poweredOn ? .blue : .secondary)
                        }
                        .disabled(trigger.state != .poweredOn)
                    } else {
                        Button("Stop Scanning", role: .cancel) {
                            trigger.stopDiscoveryScan()
                        }
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Nearby Devices")
                } footer: {
                    Text("Turn on your car and make sure its Bluetooth is discoverable. Pair the device that represents your car's audio system or hands-free kit.")
                        .font(.caption)
                }

                // No Bluetooth section
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("No Bluetooth in your car?", systemImage: "car.fill")
                            .font(.subheadline.bold())
                        Text("Use the home screen widget to start trips with one tap, or let the motion sensor auto-detect your drives.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Car Bluetooth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func pair(device: DiscoveredDevice) {
        pairedDeviceUUID = device.uuid
        pairedDeviceName = device.displayName
        trigger.stopDiscoveryScan()
    }
}

