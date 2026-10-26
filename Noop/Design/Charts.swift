import SwiftUI
import Charts

struct TrendPoint: Identifiable {
    let date: Date
    let value: Double
    var tint: Color? = nil

    var id: Date { date }
}

private func paddedDomain(_ points: [TrendPoint], zeroBased: Bool) -> ClosedRange<Double> {
    let values = points.map { $0.value }
    guard let high = values.max(), let low = values.min() else { return 0...1 }
    if zeroBased { return 0...max(high * 1.15, 1) }
    let pad = max((high - low) * 0.25, 1)
    return (low - pad)...(high + pad)
}

// MARK: - Range picker

struct RangePicker: View {
    @Binding var range: TrendRange
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TrendRange.allCases) { option in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { range = option }
                } label: {
                    Text(option.label)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(range == option ? Color.black : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if range == option {
                                Capsule()
                                    .fill(Color.white)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    let points: [TrendPoint]
    var color: Color
    var bars = false

    var body: some View {
        Chart(points) { point in
            if bars {
                BarMark(x: .value("Day", point.date, unit: .day),
                        y: .value("Value", point.value),
                        width: .fixed(4))
                    .foregroundStyle(color.opacity(0.9))
                    .cornerRadius(1.5)
            } else {
                LineMark(x: .value("Day", point.date, unit: .day),
                         y: .value("Value", point.value))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(color)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: paddedDomain(points, zeroBased: bars))
        .chartLegend(.hidden)
    }
}

// MARK: - Interactive trend chart

/// Thin line or bar chart. Drag across it to read exact values.
struct TrendChart: View {
    enum Style { case line, bar }

    let points: [TrendPoint]
    var color: Color
    var style: Style = .line
    var format: (Double) -> String = { String(Int($0.rounded())) }
    var height: CGFloat = 140

    @State private var selectedDate: Date?

    private var selectedPoint: TrendPoint? {
        guard let target = selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) }
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                if style == .line {
                    LineMark(x: .value("Day", point.date, unit: .day),
                             y: .value("Value", point.value))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(color)
                } else {
                    BarMark(x: .value("Day", point.date, unit: .day),
                            y: .value("Value", point.value))
                        .foregroundStyle(point.tint ?? color)
                        .cornerRadius(2)
                }
            }
            if let selected = selectedPoint {
                RuleMark(x: .value("Day", selected.date, unit: .day))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 1) {
                            Text(format(selected.value))
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(.white)
                            Text(selected.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: paddedDomain(points, zeroBased: style == .bar))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.07))
                AxisValueLabel()
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .chartLegend(.hidden)
        .frame(height: height)
    }
}

// MARK: - Sleep timeline

/// Horizontal hypnogram: one block per sleep stage, awake at the top and deep at the bottom.
struct HypnogramView: View {
    let night: SleepNight

    var body: some View {
        Chart(night.segments) { segment in
            RectangleMark(xStart: .value("Start", segment.start),
                          xEnd: .value("End", segment.end),
                          y: .value("Stage", segment.stage.rawValue),
                          height: .fixed(15))
                .foregroundStyle(Theme.stageColor(segment.stage))
                .cornerRadius(3)
        }
        .chartYScale(domain: ["Awake", "REM", "Light", "Deep"])
        .chartXScale(domain: night.onset...night.wake)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.07))
                AxisValueLabel(format: .dateTime.hour())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .chartLegend(.hidden)
        .frame(height: 170)
    }
}
