//
//  GradeDetails.swift
//  shishanyouni
//
//  成绩明细的按需加载与居中弹窗 UI。
//  GradeService 仍负责请求和 HTML 解析；GradeView 只负责决定何时展示此弹窗。
//

import SwiftUI

/// 通行证用户点击教务系统成绩卡片后显示的居中弹窗。
struct GradeDetailPopup: View
{
    let grade: Grade
    let cookie: String?
    let fallbackStudentID: String
    let fallbackYear: String
    let fallbackTerm: String
    let gradeService: GradeService
    let onDismiss: () -> Void

    @State private var components: [GradeComponent] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var detailComponents: [GradeComponent]
    {
        components.filter { !$0.isOverallScore }
    }

    private var overallScore: String
    {
        components.first(where: \.isOverallScore)?.scoreText ?? grade.cj
    }

    var body: some View
    {
        VStack(spacing: 16)
        {
            ZStack
            {
                Text(grade.kcmc)
                    .font(.system(size: 18, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 36)

                HStack
                {
                    Spacer()
                    Button(action: onDismiss)
                    {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isLoading
            {
                ProgressView("正在加载成绩明细…")
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
            else if let errorMessage
            {
                VStack(spacing: 10)
                {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            }
            else
            {
                GradeCompositionRing(
                    components: detailComponents,
                    overallScore: overallScore
                )
                .frame(width: 132, height: 132)

                ScrollView
                {
                    VStack(spacing: 14)
                    {
                        ForEach(detailComponents)
                        { component in
                            GradeComponentRow(component: component)
                        }

                        if detailComponents.isEmpty
                        {
                            Text("教务系统没有返回成绩组成项")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 250)
            }
        }
        .padding(20)
        .frame(maxWidth: 500)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .task(id: grade.id)
        {
            await loadComponents()
        }
    }

    private func loadComponents() async
    {
        isLoading = true
        errorMessage = nil

        do
        {
            components = try await gradeService.fetchGradeComponents(
                for: grade,
                cookie: cookie,
                fallbackStudentID: fallbackStudentID,
                fallbackYear: fallbackYear,
                fallbackTerm: fallbackTerm
            )
        }
        catch
        {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct GradeComponentRow: View
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

private struct GradeCompositionRing: View
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
