//
//  AdvancedStatsView.swift
//  shishanyouni
//
//  高级统计面板：学期总览、周学时趋势、科目占比、时间热力图
//

import SwiftUI

struct AdvancedStatsView: View {
    let courses: [Course]
    let semesterStartDate: Date
    let currentWeek: Int

    @State private var showDonutChart = true

    struct SemesterOverview {
        let totalCourses: Int
        let totalPeriods: Int
        let totalHours: Double
        let peakDay: String
        let peakDayPeriods: Int
        let avgDailyPeriods: Double
        let totalWeeksWithClasses: Int
    }

    struct WeeklyData: Identifiable {
        let id: Int
        let week: Int
        let periods: Int
        let courseNames: [String]
        let maxPeriods: Int
    }

    struct SlotHeat: Identifiable {
        let id: String
        let day: Int
        let period: Int
        let occupancy: Double
    }

    var overview: SemesterOverview {
        let allCourses = courses
        let totalPeriods = allCourses.reduce(0) { acc, c in acc + c.step * c.weekList.count }
        let totalWeeks = Set(allCourses.flatMap(\.weekList)).count

        var dayPeriods: [Int: Int] = [:]
        for c in allCourses {
            dayPeriods[c.day, default: 0] += c.step * c.weekList.count
        }
        let peak = dayPeriods.max(by: { $0.value < $1.value }) ?? (1, 0)
        let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let avgDaily = totalWeeks > 0 ? Double(totalPeriods) / Double(totalWeeks * 7) : 0

        return SemesterOverview(
            totalCourses: Set(allCourses.map(\.name)).count,
            totalPeriods: totalPeriods,
            totalHours: Double(totalPeriods) * 0.75,
            peakDay: weekdays[(peak.key - 1) % 7],
            peakDayPeriods: peak.value,
            avgDailyPeriods: avgDaily,
            totalWeeksWithClasses: totalWeeks
        )
    }

    var weeklyData: [WeeklyData] {
        let allWeeks = Set(courses.flatMap(\.weekList)).sorted()
        let maxP = allWeeks.map { week in
            courses.filter { $0.weekList.contains(week) }.reduce(0) { $0 + $1.step }
        }.max() ?? 1
        return allWeeks.map { week in
            let weekCourses = courses.filter { $0.weekList.contains(week) }
            return WeeklyData(
                id: week,
                week: week,
                periods: weekCourses.reduce(0) { $0 + $1.step },
                courseNames: weekCourses.map(\.name),
                maxPeriods: maxP
            )
        }
    }

    var subjectDistribution: [(name: String, periods: Int, ratio: Double)] {
        var dict: [String: Int] = [:]
        for c in courses {
            dict[c.name, default: 0] += c.step * c.weekList.count
        }
        let total = dict.values.reduce(0, +)
        return dict.map { ($0.key, $0.value, total > 0 ? Double($0.value) / Double(total) : 0) }
            .sorted { $0.1 > $1.1 }
    }

    var slotHeatmap: [SlotHeat] {
        let totalWeeks = Set(courses.flatMap(\.weekList)).count
        var heat: [SlotHeat] = []
        for day in 1...7 {
            for period in 1...12 {
                let weeksOccupied = courses.filter { c in
                    c.day == day && c.start <= period && c.endPeriod >= period
                }.flatMap(\.weekList).reduce(into: Set<Int>()) { $0.insert($1) }.count
                let occupancy = totalWeeks > 0 ? Double(weeksOccupied) / Double(totalWeeks) : 0
                heat.append(SlotHeat(id: "\(day)_\(period)", day: day, period: period, occupancy: occupancy))
            }
        }
        return heat
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overviewSection
                weeklyTrendSection
                subjectSection
                heatmapSection
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .navigationTitle("学期统计")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - 学期总览

    private var overviewSection: some View {
        VStack(spacing: 12) {
            Text("学期总览")
                .font(.title3).fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                statCell(title: "课程门数", value: "\(overview.totalCourses)", icon: "book.closed.fill", color: .blue)
                statCell(title: "总学时", value: String(format: "%.0f", overview.totalHours), suffix: "h", icon: "clock.arrow.2.circlepath", color: .orange)
                statCell(title: "最忙天", value: overview.peakDay, suffix: " \(overview.peakDayPeriods)节", icon: "chart.bar.fill", color: .red)
                statCell(title: "日均课时", value: String(format: "%.1f", overview.avgDailyPeriods), suffix: "节/天", icon: "calendar.badge.clock", color: .green)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statCell(title: String, value: String, suffix: String = "", icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption).foregroundColor(color)
                Text(title).font(.caption).foregroundColor(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(.title2, design: .rounded)).fontWeight(.bold)
                if !suffix.isEmpty {
                    Text(suffix).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 周学时趋势

    private var weeklyTrendSection: some View {
        VStack(spacing: 12) {
            Text("周学时趋势")
                .font(.title3).fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            if weeklyData.isEmpty {
                Text("暂无课表数据")
                    .foregroundColor(.secondary).padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(weeklyData) { wd in
                            VStack(spacing: 4) {
                                Text("\(wd.periods)")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(wd.week == currentWeek ? .white : .secondary)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(wd.week == currentWeek ? Color.blue : Color.blue.opacity(0.3))
                                    .frame(width: 18, height: max(4, CGFloat(wd.periods) / CGFloat(max(wd.maxPeriods, 1)) * 120))

                                Text("\(wd.week)")
                                    .font(.system(size: 9))
                                    .foregroundColor(wd.week == currentWeek ? .blue : .secondary)
                            }
                            .padding(.horizontal, 2)
                            .padding(.vertical, 4)
                            .background(wd.week == currentWeek ? Color.blue.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .frame(height: 180)
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 科目占比

    private var subjectSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("科目占比（全学期）")
                    .font(.title3).fontWeight(.bold)

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        showDonutChart.toggle()
                    }
                }) {
                    Image(systemName: showDonutChart ? "chart.pie.fill" : "chart.pie")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if subjectDistribution.isEmpty {
                Text("暂无数据").foregroundColor(.secondary)
            } else {
                if showDonutChart {
                    donutChartView
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(subjectDistribution.prefix(6).enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: 6) {
                                Circle().fill(subjectColors[idx % subjectColors.count]).frame(width: 8, height: 8)
                                Text(item.name).font(.system(size: 12)).lineLimit(1)
                                Spacer()
                                Text(String(format: "%.0f%%", item.ratio * 100))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        if subjectDistribution.count > 6 {
                            Text("...及其他 \(subjectDistribution.count - 6) 门")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var donutChartView: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                ForEach(Array(subjectDonutSegments.enumerated()), id: \.offset) { index, seg in
                    DonutSliceShape(startAngle: seg.start, endAngle: seg.end, innerRadiusRatio: 0.5)
                        .fill(subjectColors[index % subjectColors.count])
                }
                Circle().fill(Color(.systemBackground)).frame(width: 56, height: 56)
                VStack(spacing: 0) {
                    Text("\(overview.totalPeriods)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("总节次")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var subjectDonutSegments: [(start: Angle, end: Angle)] {
        var segments: [(Angle, Angle)] = []
        var current: Double = -90
        for item in subjectDistribution {
            let delta = item.ratio * 360
            segments.append((Angle(degrees: current), Angle(degrees: current + delta)))
            current += delta
        }
        return segments
    }

    private let subjectColors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red,
        .teal, .indigo, .cyan, .mint, .brown,
        Color(red: 0.5, green: 0.2, blue: 0.8),
        Color(red: 0.9, green: 0.3, blue: 0.5),
        Color(red: 0.2, green: 0.6, blue: 0.4),
        Color(red: 0.4, green: 0.7, blue: 0.9),
    ]

    // MARK: - 时间热力图

    private var heatmapSection: some View {
        VStack(spacing: 12) {
            Text("空档热力图")
                .font(.title3).fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("颜色越深表示该时段占用率越高，越浅表示自由时间越多")
                .font(.caption).foregroundColor(.secondary)

            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Text("").frame(width: 28)
                    ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { d in
                        Text(d).font(.system(size: 10)).frame(maxWidth: .infinity)
                    }
                }

                ForEach(0..<12, id: \.self) { row in
                    let period = row + 1
                    HStack(spacing: 2) {
                        Text("\(period)").font(.system(size: 9)).foregroundColor(.secondary).frame(width: 28)

                        ForEach(1...7, id: \.self) { day in
                            let slot = slotHeatmap.first { $0.day == day && $0.period == period }
                            let occ = slot?.occupancy ?? 0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(heatColor(occupancy: occ))
                                .frame(height: 20)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color(.secondarySystemBackground).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 16) {
                heatLegend(color: .green.opacity(0.2), label: "空闲")
                heatLegend(color: .yellow, label: "一般")
                heatLegend(color: .orange, label: "较忙")
                heatLegend(color: .red, label: "爆满")
            }
            .font(.caption2)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func heatColor(occupancy: Double) -> Color {
        switch occupancy {
        case 0: return Color.green.opacity(0.15)
        case ..<0.25: return Color.green.opacity(0.4)
        case ..<0.5: return Color.yellow.opacity(0.6)
        case ..<0.75: return Color.orange.opacity(0.75)
        default: return Color.red.opacity(0.85)
        }
    }

    private func heatLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
            Text(label)
        }
    }
}

#Preview {
    NavigationStack {
        AdvancedStatsView(
            courses: [],
            semesterStartDate: Date(),
            currentWeek: 1
        )
    }
}
