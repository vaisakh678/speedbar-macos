import SwiftUI

/// The bordered history chart, styled after Hot's sensor graph: a rounded card
/// with faint gridlines, the series drawn over them, and a legend underneath.
struct TrafficGraphCard: View {
    let samples: [SpeedSample]
    let unit: RateUnit

    private let capacity = SpeedMonitor.historyLength
    private let gridLines = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            chart
                .frame(height: 78)
            legend
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(.quaternary.opacity(0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
        .padding(.horizontal, MenuMetrics.horizontalInset)
    }

    private var chart: some View {
        Canvas { context, size in
            // Gridlines first so the series sits on top of them.
            var grid = Path()
            for index in 0...gridLines {
                let y = size.height * CGFloat(index) / CGFloat(gridLines)
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(.secondary.opacity(0.18)), lineWidth: 0.5)

            guard samples.count > 1 else { return }

            // Scale to the window's own peak so quiet stretches still show
            // shape, with a floor so idle noise is not magnified into mountains.
            let peak = max(
                samples.map(\.download).max() ?? 0,
                samples.map(\.upload).max() ?? 0,
                16_384
            )

            let step = size.width / CGFloat(capacity - 1)
            let leading = size.width - step * CGFloat(samples.count - 1)

            func series(_ value: (SpeedSample) -> Double) -> Path {
                var path = Path()
                for (index, sample) in samples.enumerated() {
                    let x = leading + step * CGFloat(index)
                    let y = size.height - size.height * CGFloat(value(sample) / peak)
                    let point = CGPoint(x: x, y: min(max(y, 0.5), size.height - 0.5))
                    index == 0 ? path.move(to: point) : path.addLine(to: point)
                }
                return path
            }

            context.stroke(series(\.download), with: .color(Self.downloadColor), lineWidth: 1.5)
            context.stroke(series(\.upload), with: .color(Self.uploadColor), lineWidth: 1.5)
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: Self.downloadColor, title: "Download")
            legendItem(color: Self.uploadColor, title: "Upload")
            Spacer()
            if let peak = samples.map(\.download).max(), peak > 0 {
                Text("peak \(RateFormatter.string(bytesPerSecond: peak, as: unit))")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: 10))
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .foregroundStyle(.secondary)
        }
    }

    static let downloadColor = Color(red: 0.36, green: 0.66, blue: 1.0)
    static let uploadColor = Color(red: 1.0, green: 0.62, blue: 0.24)
}
