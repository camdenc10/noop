import SwiftUI
import CoreBluetooth

struct SensorSheet: View {
    @Environment(SensorMonitor.self) private var sensor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Sensor")
                            .font(.system(size: 30, weight: .heavy))
                            .fontWidth(.condensed)
                            .foregroundStyle(.white)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Theme.card, in: Circle())
                        }
                    }
                    .padding(.top, 20)

                    if sensor.isConnected { connectedCard } else { scanCard }

                    Text("Works with sensors that use the standard Bluetooth Heart Rate service, such as chest straps and many armbands. The battery percentage appears only if the sensor reports it through the standard Battery service. Proprietary protocols are not used.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 16)
            }
        }
        .onAppear { if !sensor.isConnected { sensor.startScanning() } }
        .onDisappear { sensor.stopScanning() }
        .presentationDragIndicator(.visible)
    }

    private var connectedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Connected", color: Theme.green)
            Text(sensor.connectedName ?? "Sensor")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            HStack {
                MetricLine(label: "Battery", value: sensor.batteryLevel.map { "\($0)" } ?? "—",
                           unit: sensor.batteryLevel == nil ? "" : "%")
                Spacer()
                MetricLine(label: "Live HR", value: sensor.bpm.map { "\($0)" } ?? "—",
                           unit: sensor.bpm == nil ? "" : "bpm")
            }
            if sensor.batteryLevel == nil {
                Text("This sensor doesn't report its battery.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            Button { sensor.disconnect() } label: {
                Text("Disconnect")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
        .card()
    }

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(text: "Nearby sensors", color: .white)
                Spacer()
                if sensor.isScanning { ProgressView().tint(Theme.green) }
            }
            if sensor.bluetoothState == .poweredOff {
                note("Bluetooth is off. Turn it on in Control Center.")
            } else if sensor.bluetoothState == .unauthorized {
                note("Noop doesn't have Bluetooth permission. Allow it in Settings > Noop.")
            } else if sensor.discovered.isEmpty {
                note("Looking for sensors. Make sure yours is awake and not connected to another app.")
            }
            ForEach(sensor.discovered) { found in
                Button { sensor.connect(found) } label: {
                    HStack {
                        Text(found.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(found.rssi) dBm")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
    }
}
