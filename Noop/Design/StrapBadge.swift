import SwiftUI

/// Outline of a fitness band with a slot, drawn as a stroke.
struct StrapIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.addRoundedRect(in: CGRect(x: 0, y: 0, width: w, height: h),
                            cornerSize: CGSize(width: w * 0.38, height: w * 0.38))
        path.addRoundedRect(in: CGRect(x: w * 0.27, y: h * 0.32, width: w * 0.46, height: h * 0.36),
                            cornerSize: CGSize(width: w * 0.14, height: w * 0.14))
        return path
    }
}

/// Top-right status: battery percentage in muted gray, band icon, green dot while connected.
/// Tapping opens the sensor sheet. With no sensor paired it shows only the dimmed icon.
struct StrapBadge: View {
    let level: Int?
    let isConnected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let level = level {
                    Text("\(level)%")
                        .font(.system(size: 20, weight: .bold))
                        .fontWidth(.condensed)
                        .monospacedDigit()
                        .foregroundStyle(level <= 15 ? Theme.red : Color(hex: 0x9A9DA3))
                }
                StrapIcon()
                    .stroke(isConnected ? Color.white : Color.white.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                    .frame(width: 19, height: 27)
                    .overlay(alignment: .topTrailing) {
                        if isConnected {
                            Circle()
                                .fill(Color(hex: 0x3DDB85))
                                .frame(width: 9, height: 9)
                                .offset(x: 3.5, y: -3)
                        }
                    }
                    .padding(.trailing, 3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isConnected
                            ? "Sensor connected" + (level.map { ", battery \($0) percent" } ?? "")
                            : "Connect a heart rate sensor")
    }
}
