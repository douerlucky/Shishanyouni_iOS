//
//  ScheduleStatsView.swift
//  shishanyouni
//
//  课表统计卡片：本周课时统计 + 科目占比
//

import SwiftUI

struct SubjectStat: Identifiable {
    let id = UUID()
    let name: String
    let periods: Int
    let color: Color
    let ratio: Double
}

struct ScheduleStatsView: View {
    let stats: [SubjectStat]
    let totalPeriods: Int
    let freeSlots: Int

    @State private var showDonutChart = true

    var body: some View {
        if stats.isEmpty {
            emptyStateView
        } else {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    if showDonutChart {
                        donutChart
                            .transition(.scale.combined(with: .opacity))
                    }
                    infoPanel
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: showDonutChart)
        }
    }

    private var emptyStateView: some View {
        HStack {
            Image(systemName: "chart.pie")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("本周暂无课程安排")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private var donutChart: some View {
        ZStack {
            ForEach(Array(donutSegments.enumerated()), id: \.offset) { index, segment in
                DonutSliceShape(startAngle: segment.start, endAngle: segment.end)
                    .fill(stats[index].color)
            }

            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 44, height: 44)

            VStack(spacing: 0) {
                Text("\(totalPeriods)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("节")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 80, height: 80)
    }

    private var donutSegments: [(start: Angle, end: Angle)] {
        var segments: [(Angle, Angle)] = []
        var currentAngle: Double = -90
        for stat in stats {
            let delta = stat.ratio * 360
            segments.append((Angle(degrees: currentAngle), Angle(degrees: currentAngle + delta)))
            currentAngle += delta
        }
        return segments
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("本周课时统计")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { showDonutChart.toggle() }) {
                    Image(systemName: showDonutChart ? "chart.pie.fill" : "chart.pie")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            ForEach(stats.prefix(5)) { stat in
                HStack(spacing: 6) {
                    Circle()
                        .fill(stat.color)
                        .frame(width: 8, height: 8)
                    Text(stat.name)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(stat.periods)节")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            if stats.count > 5 {
                Text("...及其他 \(stats.count - 5) 门课程")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if freeSlots > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("空闲 \(freeSlots) 个时段")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.green)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func compute(from courses: [Course], week: Int) -> (stats: [SubjectStat], totalPeriods: Int, freeSlots: Int) {
        let weekCourses = courses.filter { $0.parsedWeeks.contains(week) }
        var subjectPeriods: [String: (periods: Int, color: Color)] = [:]

        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .red,
            .teal, .indigo, .cyan, .mint, .brown,
        ]

        var colorIndex = 0
        for course in weekCourses {
            let key = course.name
            if subjectPeriods[key] == nil {
                subjectPeriods[key] = (0, colors[colorIndex % colors.count])
                colorIndex += 1
            }
            subjectPeriods[key]?.periods += course.step
        }

        let totalPeriods = subjectPeriods.values.reduce(0) { $0 + $1.periods }
        let totalSlots = 7 * 12
        var occupiedSlots: Set<String> = []
        for course in weekCourses {
            for period in course.start...course.endPeriod {
                occupiedSlots.insert("\(course.day)_\(period)")
            }
        }
        let freeSlots = totalSlots - occupiedSlots.count

        let sortedStats = subjectPeriods
            .map { SubjectStat(
                name: $0.key,
                periods: $0.value.periods,
                color: $0.value.color,
                ratio: totalPeriods > 0 ? Double($0.value.periods) / Double(totalPeriods) : 0
            )}
            .sorted { $0.periods > $1.periods }

        return (sortedStats, totalPeriods, freeSlots)
    }
}

struct DonutSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadiusRatio: CGFloat

    init(startAngle: Angle, endAngle: Angle, innerRadiusRatio: CGFloat = 0.55) {
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.innerRadiusRatio = innerRadiusRatio
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * innerRadiusRatio
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

#Preview {
    let dummyStats = [
        SubjectStat(name: "高等数学", periods: 6, color: .blue, ratio: 0.35),
        SubjectStat(name: "大学英语", periods: 4, color: .green, ratio: 0.24),
        SubjectStat(name: "程序设计", periods: 4, color: .orange, ratio: 0.24),
        SubjectStat(name: "体育", periods: 3, color: .purple, ratio: 0.17),
    ]
    return ScheduleStatsView(stats: dummyStats, totalPeriods: 17, freeSlots: 67)
}
