import SwiftUI

/// Plain-language description of every formula. Numbers come from ScoringEngine, so this
/// screen cannot drift out of sync with the real calculation.
struct MethodologyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("How scores work")
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

                    section("Recovery, 0-100",
                            "Compares last night with your own recent normal. Baselines are the average of your previous \(ScoringEngine.baselineWindowDays) days and need at least \(ScoringEngine.minBaselineDays) days of data.",
                            [("HRV", "\(pct(ScoringEngine.weightHRV))", "Higher than baseline raises the score. 50 + 150 × (HRV ÷ baseline − 1)."),
                             ("Resting heart rate", "\(pct(ScoringEngine.weightRHR))", "Lower than baseline raises the score. 50 + 8 points per bpm below."),
                             ("Sleep performance", "\(pct(ScoringEngine.weightSleep))", "Your sleep performance score, as is."),
                             ("Respiratory rate", "\(pct(ScoringEngine.weightResp))", "Lower than baseline raises the score. 50 + 40 per breath below.")],
                            footer: "If a signal is missing, the remaining weights are scaled up to fill 100%. Without HRV and resting heart rate there is no score. Green is 70 and up, yellow 40-69, red below 40.")

                    section("Strain, 0-21",
                            "Time in heart rate zones, weighted by intensity, then squeezed onto a 0-21 scale.",
                            zoneRows,
                            footer: "Load = Σ minutes × weight. Strain = 21 × (1 − e^(−load ÷ \(Int(ScoringEngine.strainScale)))). Needs at least 20 heart rate readings in the day. Zones are percentages of your max heart rate.")

                    section("Sleep",
                            nil,
                            [("Need", "", "Your baseline, plus 6 minutes for each strain point above 10 the day before (up to 60 min), plus 20% of the last three nights' shortfall (up to 60 min)."),
                             ("Performance", "", "Time asleep ÷ need, capped at 100%."),
                             ("Debt", "", "Shortfalls over the last 7 nights, never below zero."),
                             ("Consistency", "", "How much bedtime and wake time vary over 5 nights. Zero variation is 100; a 90 minute average spread is 0.")],
                            footer: nil)

                    section("About HRV",
                            "Apple Health records HRV as SDNN. Some other devices report RMSSD. They are different measures and not interchangeable, so Noop compares you only against your own SDNN history.",
                            [], footer: "These formulas are simple and open on purpose. They are estimates for personal insight, not medical advice and not a diagnosis.")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func pct(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    private var zoneRows: [(String, String, String)] {
        (0..<5).map { i in
            ("Zone \(i + 1)", "×\(Int(ScoringEngine.zoneWeights[i]))",
             "From \(Int(ScoringEngine.zoneLowerBounds[i] * 100))% of max heart rate")
        }
    }

    private func section(_ title: String, _ intro: String?, _ rows: [(String, String, String)],
                         footer: String?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: title, color: Theme.green)
            if let intro = intro {
                Text(intro)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(row.0).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        Spacer()
                        Text(row.1).font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.green)
                    }
                    Text(row.2)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let footer = footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }
}
