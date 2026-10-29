import SwiftUI

struct GradeComponentRow: View
{
    let component: GradeComponent

    private var color: Color
    {
        gradeDetailColor(for: component.scoreText)
    }

    var body: some View
    {
        HStack(spacing: 8)
        {
            Text(component.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .frame(width: 72, alignment: .leading)

            GeometryReader
            { proxy in
                ZStack(alignment: .leading)
                {
                    Capsule().fill(color.opacity(0.16))
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: proxy.size.width * component.normalizedScore)
                }
            }
            .frame(height: 9)

            Text(component.percentageText ?? "—")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            Text(component.scoreText)
                .font(.system(
                    size: component.scoreText.contains(".") ? 15 : 17,
                    weight: .bold,
                    design: .rounded
                ))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
                .frame(width: 60, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GradeCompositionRing: View
{
    private struct Segment: Identifiable
    {
        let id: String
        let start: Double
        let end: Double
        let progress: Double
        let color: Color
    }

    let components: [GradeComponent]
    let overallScore: String

    private var segments: [Segment]
    {
        guard !components.isEmpty else { return [] }

        let knownTotal = components.compactMap(\.percentageValue).reduce(0, +)
        let missing = components.filter { $0.percentageValue == nil }.count
        let fallback = missing > 0 ? max(100 - knownTotal, 0) / Double(missing) : 0
        let weights = components.map { max($0.percentageValue ?? fallback, 0) }
        let denominator = max(weights.reduce(0, +), 100)

        var cursor = 0.0
        return components.enumerated().map
        { index, component in
            let start = cursor
            let end = min(start + weights[index] / denominator, 1)
            cursor = end
            return Segment(
                id: component.id,
                start: start,
                end: end,
                progress: component.normalizedScore,
                color: gradeDetailColor(for: component.scoreText)
            )
        }
    }

    var body: some View
    {
        ZStack
        {
            ForEach(segments)
            { segment in
                let length = segment.end - segment.start
                let margin = segments.count > 1 ? min(0.025, length * 0.2) : 0
                let start = min(segment.start + margin, segment.end)
                let end = max(segment.end - margin, start)
                let filledEnd = start + (end - start) * segment.progress

                Circle()
                    .trim(from: start, to: end)
                    .stroke(segment.color.opacity(0.18), style: StrokeStyle(lineWidth: 13, lineCap: .round))
                Circle()
                    .trim(from: start, to: filledEnd)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: 13, lineCap: .round))
            }
            .rotationEffect(.degrees(-90))

            VStack(spacing: 2)
            {
                Text(overallScore)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeDetailColor(for: overallScore))
                Text("总评")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func gradeDetailColor(for scoreText: String) -> Color
{
    let score = Double(scoreText) ?? 0
    switch score
    {
    case 90...: return .green
    case 80..<90: return .blue
    case 70..<80: return .orange
    case 60..<70: return .yellow
    default: return .red
    }
}
