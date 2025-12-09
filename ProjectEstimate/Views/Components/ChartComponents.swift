//
//  ChartComponents.swift
//  ProjectEstimate
//
//  Custom chart components for estimate visualization
//  Uses Swift Charts for data representation
//

import SwiftUI
import Charts

// MARK: - Cost Breakdown Pie Chart

struct CostBreakdownPieChart: View {
    let data: [(category: String, amount: Double, color: String)]

    @State private var selectedSlice: String?

    var total: Double {
        data.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 16) {
            Chart(data, id: \.category) { item in
                SectorMark(
                    angle: .value("Amount", item.amount),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(colorForString(item.color))
                .cornerRadius(4)
                .opacity(selectedSlice == nil || selectedSlice == item.category ? 1.0 : 0.5)
            }
            .chartBackground { proxy in
                GeometryReader { geo in
                    if let selected = selectedSlice,
                       let item = data.first(where: { $0.category == selected }) {
                        let frame = geo[proxy.plotFrame!]
                        VStack(spacing: 4) {
                            Text(item.category)
                                .font(.caption.bold())
                            Text(formatCurrency(item.amount))
                                .font(.title3.bold())
                            Text("\(Int(item.amount / total * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .position(x: frame.midX, y: frame.midY)
                    } else {
                        let frame = geo[proxy.plotFrame!]
                        VStack(spacing: 4) {
                            Text("Total")
                                .font(.caption.bold())
                            Text(formatCurrency(total))
                                .font(.title3.bold())
                        }
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
            .chartAngleSelection(value: $selectedSlice)
            .frame(height: 220)

            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(data, id: \.category) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(colorForString(item.color))
                            .frame(width: 12, height: 12)
                        Text(item.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatCurrency(item.amount))
                            .font(.caption.bold())
                    }
                    .padding(.vertical, 4)
                    .onTapGesture {
                        withAnimation {
                            selectedSlice = selectedSlice == item.category ? nil : item.category
                        }
                    }
                }
            }
        }
    }

    private func colorForString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "gray", "grey": return .gray
        case "teal": return .teal
        case "yellow": return .yellow
        default: return .blue
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Cost Range Bar Chart

struct CostRangeChart: View {
    let lowCost: Double
    let highCost: Double
    let midCost: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Range")
                .font(.headline)

            GeometryReader { geo in
                let width = geo.size.width

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 24)

                    // Range fill
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.green, .yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width, height: 24)

                    // Midpoint indicator
                    let midPosition = width * CGFloat(midCost / highCost)
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                        .offset(x: midPosition - 8)
                }
            }
            .frame(height: 24)

            HStack {
                VStack(alignment: .leading) {
                    Text("Low")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(lowCost))
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }

                Spacer()

                VStack {
                    Text("Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(midCost))
                        .font(.subheadline.bold())
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("High")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(highCost))
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Timeline Chart

struct TimelineChart: View {
    let estimatedDaysLow: Int
    let estimatedDaysHigh: Int
    let phases: [TimelinePhase]

    struct TimelinePhase: Identifiable {
        let id = UUID()
        let name: String
        let daysLow: Int
        let daysHigh: Int
        let color: Color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Timeline")
                .font(.headline)

            Text("\(estimatedDaysLow) - \(estimatedDaysHigh) days")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            if !phases.isEmpty {
                VStack(spacing: 8) {
                    ForEach(phases) { phase in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(phase.color)
                                .frame(width: 12, height: 12)

                            Text(phase.name)
                                .font(.subheadline)

                            Spacer()

                            Text("\(phase.daysLow)-\(phase.daysHigh) days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Visual timeline bar
            GeometryReader { geo in
                let totalDays = Double(estimatedDaysHigh)
                let dayWidth = geo.size.width / totalDays

                HStack(spacing: 0) {
                    ForEach(phases) { phase in
                        let avgDays = Double(phase.daysLow + phase.daysHigh) / 2
                        RoundedRectangle(cornerRadius: 4)
                            .fill(phase.color)
                            .frame(width: avgDays * dayWidth)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 20)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Trend?

    enum Trend {
        case up(String)
        case down(String)
        case neutral
    }

    init(
        title: String,
        value: String,
        icon: String,
        color: Color = .blue,
        trend: Trend? = nil
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.trend = trend
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)

                Spacer()

                if let trend = trend {
                    trendView(trend)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
    }

    @ViewBuilder
    private func trendView(_ trend: Trend) -> some View {
        switch trend {
        case .up(let value):
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                Text(value)
            }
            .font(.caption.bold())
            .foregroundStyle(.green)

        case .down(let value):
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.right")
                Text(value)
            }
            .font(.caption.bold())
            .foregroundStyle(.red)

        case .neutral:
            Text("—")
                .font(.caption.bold())
                .foregroundStyle(.gray)
        }
    }
}

// MARK: - Preview

#Preview("Chart Components") {
    ScrollView {
        VStack(spacing: 24) {
            CostBreakdownPieChart(data: [
                ("Labor", 15000, "blue"),
                ("Materials", 12000, "green"),
                ("Permits", 2000, "orange"),
                ("Contingency", 3000, "red")
            ])
            .padding()

            CostRangeChart(
                lowCost: 25000,
                highCost: 45000,
                midCost: 35000
            )
            .padding()

            TimelineChart(
                estimatedDaysLow: 14,
                estimatedDaysHigh: 21,
                phases: [
                    .init(name: "Demo", daysLow: 2, daysHigh: 3, color: .red),
                    .init(name: "Rough Work", daysLow: 5, daysHigh: 7, color: .orange),
                    .init(name: "Finish Work", daysLow: 5, daysHigh: 8, color: .blue),
                    .init(name: "Final", daysLow: 2, daysHigh: 3, color: .green)
                ]
            )
            .padding()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                StatCard(
                    title: "Total Projects",
                    value: "24",
                    icon: "folder.fill",
                    color: .blue,
                    trend: .up("+3")
                )

                StatCard(
                    title: "Total Value",
                    value: "$1.2M",
                    icon: "dollarsign.circle.fill",
                    color: .green,
                    trend: .up("+12%")
                )
            }
            .padding()
        }
    }
}
