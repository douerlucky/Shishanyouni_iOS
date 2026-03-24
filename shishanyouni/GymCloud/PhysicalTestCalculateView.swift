//
//  PhysicalTestCalculateView.swift
//  shishanyouni
//
//  Created by douer_lucky on 2026/3/24.
//

import SwiftUI

// MARK: - 计算器专用数据模型

struct CalcPhysicalDetail: Identifiable
{
    let id = UUID()
    var project: String
    var result: String = "" // 用户输入内容
    var score: String = "-" // 计算后的单项分
    var grade: String = "待输入" // 等级：不及格/及格/良好/优秀
    var isBMI: Bool = false
}

// MARK: - 主视图

struct PhysicalTestCalculatorView: View
{
    // 基础信息
    @State private var gender: String = "未选择"
    @State private var gradeLevel: String = "大一"
    @State private var height: String = ""
    @State private var weight: String = ""

    // 各项成绩状态
    @State private var details: [CalcPhysicalDetail] = [
        CalcPhysicalDetail(project: "BMI", isBMI: true),
        CalcPhysicalDetail(project: "肺活量"),
        CalcPhysicalDetail(project: "50米跑"),
        CalcPhysicalDetail(project: "1000米跑"),
        CalcPhysicalDetail(project: "800米跑"),
        CalcPhysicalDetail(project: "坐位体前屈"),
        CalcPhysicalDetail(project: "立定跳远"),
        CalcPhysicalDetail(project: "引体向上"),
        CalcPhysicalDetail(project: "仰卧起坐"),
    ]

    // 总分显示
    @State private var totalScore: Double = 0
    @State private var totalGrade: String = "-"

    // 交互状态
    @State private var selectedYear = "2026-2027"
    @State private var showPicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSaveFeedback = false
    @State private var isLoadingDefaults = false  // 防止 onChange 干扰读取

    let years = ["2026-2027", "2025-2026", "2024-2025", "2023-2024", "2022-2023"]
    let gradeLevels = ["大一", "大二", "大三", "大四", "大五"]

    // BMI 逻辑计算
    var bmiValue: Double
    {
        guard let h = Double(height), let w = Double(weight), h > 0 else { return 0 }
        return w / ((h / 100) * (h / 100))
    }

    var bmiResult: String
    {
        guard bmiValue > 0 else { return "" }
        return String(format: "%.1f", bmiValue)
    }

    var body: some View
    {
        ZStack(alignment: .bottom)
        {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            ScrollView
            {
                VStack(alignment: .leading, spacing: 25)
                {
                    // MARK: 1. 顶部总分环 (Reactive!)

                    HStack(spacing: 30)
                    {
                        MainScoreRing(score: totalScore, totalGrade: totalGrade)
                            .frame(width: 128, height: 128)

                        VStack(alignment: .leading, spacing: 8)
                        {
                            Text("预测年度: \(selectedYear)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("输入数据即刻计算分值")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, 16)

                    // MARK: 2. 基础信息区 (身高体重放一排)

                    VStack(alignment: .leading, spacing: 16)
                    {
                        // 性别选择
                        HStack
                        {
                            Text("性别").font(.system(size: 16, weight: .medium)).foregroundColor(.secondary)
                            Spacer()
                            Picker("性别", selection: $gender)
                            {
                                Text("未选择").tag("未选择")
                                Text("男").tag("男")
                                Text("女").tag("女")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                            .onChange(of: gender) { _ in if !isLoadingDefaults { resetAndCalculate() } }
                        }

                        Divider()

                        // 年级选择 (大一 - 大五)
                        HStack
                        {
                            Text("年级").font(.system(size: 16, weight: .medium)).foregroundColor(.secondary)
                            Spacer()
                            Picker("年级", selection: $gradeLevel)
                            {
                                ForEach(gradeLevels, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(.primary)
                            .onChange(of: gradeLevel) { _ in calculateScore() }
                        }

                        Divider()

                        // 身高体重
                        HStack(spacing: 15)
                        {
                            // 身高输入
                            InputBox(label: "身高", unit: "cm", value: $height)
                            {
                                calculateScore()
                            }
                            .disabled(gender == "未选择")
                            .opacity(gender == "未选择" ? 0.35 : 1.0)

                            // 体重输入
                            InputBox(label: "体重", unit: "kg", value: $weight)
                            {
                                calculateScore()
                            }
                            .disabled(gender == "未选择")
                            .opacity(gender == "未选择" ? 0.35 : 1.0)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 15).fill(Color(uiColor: .secondarySystemGroupedBackground)))
                    .padding(.horizontal, 16)

                    // MARK: 3. 单项成绩网格

                    VStack(alignment: .leading, spacing: 16)
                    {
                        Text("单项成绩").font(.title2.bold()).padding(.horizontal)

                        if gender == "未选择"
                        {
                            VStack(spacing: 20)
                            {
                                Image(systemName: "figure.cross.training")
                                    .font(.system(size: 60)).foregroundColor(.gray.opacity(0.3))
                                Text("请先选择性别").font(.title3).foregroundColor(.gray)
                                Text("男女标准不同，请选择后开始计算").font(.caption).foregroundColor(.gray.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity).padding(.top, 40)
                        }
                        else
                        {
                            let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible())]
                            LazyVGrid(columns: columns, spacing: 16)
                            {
                                ForEach($details)
                                { $detail in
                                    let proj = detail.project
                                    // 逻辑过滤：男生不要 800/仰卧起坐，女生不要 1000/引体向上
                                    let isMaleValid = proj != "800米跑" && proj != "仰卧起坐"
                                    let isFemaleValid = proj != "1000米跑" && proj != "引体向上"

                                    if (gender == "男" && isMaleValid) || (gender == "女" && isFemaleValid)
                                    {
                                        if detail.isBMI
                                        {
                                            CalcBMICard(bmiValue: bmiValue, bmiResult: bmiResult, gender: gender)
                                        }
                                        else
                                        {
                                            CalcDetailCard(detail: $detail) { calculateScore() }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 120)
            }

            // 底部保存按钮
            SaveScoreButton(showFeedback: $showSaveFeedback, showPicker: $showPicker, selectedYear: selectedYear)
            {
                saveToDefaults()
            }
        }
        .navigationTitle("体测计算器")
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showPicker) { termPickerView }
        .onAppear { loadFromDefaults() }
    }

    private var termPickerView: some View
    {
        VStack
        {
            Text("切换预测学年").font(.headline).padding()
            Picker("年份", selection: $selectedYear)
            {
                ForEach(years, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.wheel)
            Button("确定") { showPicker = false }.buttonStyle(.borderedProminent).padding()
        }.presentationDetents([.height(300)])
    }


    // MARK: - UserDefaults Keys
    private enum UDKey
    {
        static let selectedYear = "calc_selectedYear"
        static let gender       = "calc_gender"
        static let gradeLevel   = "calc_gradeLevel"
        static let height       = "calc_height"
        static let weight       = "calc_weight"
        static func detail(_ project: String) -> String { "calc_detail_\(project)" }
    }

    private func saveToDefaults()
    {
        let ud = UserDefaults.standard
        ud.set(selectedYear, forKey: UDKey.selectedYear)
        ud.set(gender,       forKey: UDKey.gender)
        ud.set(gradeLevel,   forKey: UDKey.gradeLevel)
        ud.set(height,       forKey: UDKey.height)
        ud.set(weight,       forKey: UDKey.weight)
        for detail in details where !detail.isBMI
        {
            ud.set(detail.result, forKey: UDKey.detail(detail.project))
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { showSaveFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0)
        {
            withAnimation { self.showSaveFeedback = false }
        }
    }

    private func loadFromDefaults()
    {
        let ud = UserDefaults.standard
        guard ud.object(forKey: UDKey.gender) != nil else { return }

        // 设置 flag，阻止 onChange(of: gender) 触发 resetAndCalculate
        isLoadingDefaults = true

        selectedYear = ud.string(forKey: UDKey.selectedYear) ?? selectedYear
        gender       = ud.string(forKey: UDKey.gender)       ?? gender
        gradeLevel   = ud.string(forKey: UDKey.gradeLevel)   ?? gradeLevel
        height       = ud.string(forKey: UDKey.height)       ?? ""
        weight       = ud.string(forKey: UDKey.weight)       ?? ""

        for i in 0 ..< details.count where !details[i].isBMI
        {
            details[i].result = ud.string(forKey: UDKey.detail(details[i].project)) ?? ""
        }

        // 等下一个 runloop 再关闭 flag，确保 onChange 已跳过后再允许正常重置
        DispatchQueue.main.async
        {
            self.isLoadingDefaults = false
            self.calculateScore()
        }
    }

    private func resetAndCalculate()
    {
        for i in 0 ..< details.count
        {
            details[i].result = ""
            details[i].score = "-"
            details[i].grade = "待输入"
        }
        calculateScore()
    }

    private func calculateScore()
    {
        guard gender != "未选择" else { return }

        var currentTotal: Double = 0

        // 1. BMI 计分 (权重 15%)
        let bmiScore = getBMIScore(bmi: bmiValue, gender: gender)
        currentTotal += bmiScore * 0.15

        // 2. 单项循环计分
        for i in 0 ..< details.count
        {
            if details[i].isBMI { continue }

            if let val = Double(details[i].result)
            {
                // 根据图片标准映射分数和等级
                let (score, grade) = ProjectStandard.score(for: details[i].project, value: val, gender: gender, gradeLevel: gradeLevel)
                details[i].score = String(format: "%.0f", score)
                details[i].grade = grade

                // 3. 权重加权 (根据图片3: BMI15%, 肺活量15%, 50m20%, 坐前屈10%, 跳远10%, 引体10%, 1000m20%)
                currentTotal += score * getWeight(for: details[i].project)
            }
            else
            {
                details[i].score = "-"
                details[i].grade = "待输入"
            }
        }

        totalScore = currentTotal
        totalGrade = ProjectStandard.totalGrade(score: currentTotal)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func getWeight(for project: String) -> Double
    {
        switch project
        {
        case "肺活量": return 0.15
        case "50米跑", "1000米跑", "800米跑": return 0.20
        default: return 0.10
        }
    }

    private func getBMIScore(bmi: Double, gender: String) -> Double
    {
        guard bmi > 0 else { return 0 }
        if gender == "男"
        {
            return (17.9 ... 23.9).contains(bmi) ? 100 : (bmi < 17.9 || (24.0 ... 27.9).contains(bmi) ? 80 : 60)
        }
        else
        {
            return (17.2 ... 23.9).contains(bmi) ? 100 : (bmi < 17.2 || (24.0 ... 27.9).contains(bmi) ? 80 : 60)
        }
    }
}

// 跑步分秒输入组件

struct TimeInputBox: View
{
    @Binding var totalResult: String // 最终存入的秒数
    var onUpdate: () -> Void

    // 内部临时变量，用于展示
    @State private var minutes: String = ""
    @State private var seconds: String = ""

    var body: some View
    {
        HStack(spacing: 4)
        {
            // 分钟输入
            TextField("分", text: $minutes)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(width: 30)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
                .onChange(of: minutes)
                { newValue in
                    minutes = newValue.filter { "0123456789".contains($0) }
                    syncToTotal()
                }

            Text("分").font(.caption).foregroundColor(.secondary)

            // 秒数输入
            TextField("秒", text: $seconds)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(width: 45)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
                .onChange(of: seconds)
                { newValue in
                    seconds = newValue.filter { "0123456789".contains($0) }
                    syncToTotal()
                }

            Text("秒").font(.caption).foregroundColor(.secondary)
        }
        .onAppear
        {
            // 初始化：从总秒数反推分秒（防止切换页面数据丢失）
            if let total = Double(totalResult), total > 0
            {
                minutes = String(Int(total) / 60)
                seconds = String(Int(total) % 60)
            }
        }
    }

    private func syncToTotal()
    {
        let m = Double(minutes) ?? 0
        let s = Double(seconds) ?? 0
        let total = m * 60 + s
        totalResult = total > 0 ? String(total) : ""
        onUpdate()
    }
}

// 输入框
struct InputBox: View
{
    let label: String
    let unit: String
    @Binding var value: String
    var onUpdate: () -> Void

    var body: some View
    {
        HStack(spacing: 6)
        {
            Text(label).font(.system(size: 14)).foregroundColor(.secondary)
            TextField("输入", text: $value)
                .keyboardType(.decimalPad) // 保持开启小数点键盘
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
                .onChange(of: value)
                { newValue in
                    // 允许数字、小数点，以及坐位体前屈可能出现的负号 "-"
                    let filtered = newValue.filter { "0123456789.-".contains($0) }
                    if filtered != newValue { value = filtered }
                    onUpdate()
                }
            Text(unit).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 25)
        }
    }
}

// MARK: - 单项卡片

struct CalcDetailCard: View
{
    @Binding var detail: CalcPhysicalDetail
    var onUpdate: () -> Void

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            Text(detail.project).font(.system(size: 15)).foregroundColor(.secondary)
            HStack
            {
                Spacer()
                MiniScoreBadge(score: Double(detail.score) ?? 0)
                Spacer()
            }
            HStack
            {
                // 1000米/800米 依然用双框
                if detail.project == "1000米跑" || detail.project == "800米跑"
                {
                    TimeInputBox(totalResult: $detail.result, onUpdate: onUpdate)
                }
                else
                {
                    TextField("输入", text: $detail.result)
                        // 统一给 decimalPad，但在 onChange 里根据项目过滤
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .frame(width: 80)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                        .onChange(of: detail.result)
                        { newValue in
                            // 定义支持小数和负号的项目
                            let decimalProjects = ["身高", "体重", "50米跑", "BMI"]
                            let minusProjects = ["坐位体前屈"]
                            let allowedChars: String
                            if minusProjects.contains(detail.project)
                            {
                                allowedChars = "0123456789.-"
                            }
                            else if decimalProjects.contains(detail.project)
                            {
                                // 允许数字、小数点、负号
                                allowedChars = "0123456789."
                            }
                            else
                            {
                                // 肺活量、立定跳远、引体、仰卧起坐等：只允许纯数字
                                allowedChars = "0123456789"
                            }

                            let filtered = newValue.filter { allowedChars.contains($0) }
                            if filtered != newValue { detail.result = filtered }

                            onUpdate()
                        }
                }

                Spacer()

                Text(detail.grade)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(gradeColor(detail.grade))
                    .padding(5).background(gradeColor(detail.grade).opacity(0.15)).clipShape(Capsule())
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(uiColor: .secondarySystemGroupedBackground)).shadow(color: .black.opacity(0.05), radius: 8))
    }

    private func gradeColor(_ grade: String) -> Color
    {
        if grade == "优秀" { return .green }
        if grade == "良好" { return .blue }
        if grade == "及格" { return .orange }
        if grade == "不及格" { return .red }
        return .secondary
    }
}

// MARK: - BMI 卡片

struct CalcBMICard: View
{
    let bmiValue: Double
    let bmiResult: String
    let gender: String
    var grade: String
    {
        guard bmiValue > 0 else { return "待输入" }
        if gender == "男"
        {
            if bmiValue >= 17.9 && bmiValue <= 23.9
            {
                return "正常"
            }
            else if bmiValue <= 17.8
            {
                return "低体重"
            }
            else if bmiValue >= 24.0 && bmiValue <= 27.9
            {
                return "超重"
            }
            else
            {
                return "肥胖"
            }
        }
        else
        {
            if bmiValue >= 17.2 && bmiValue <= 23.9
            {
                return "正常"
            }
            else if bmiValue <= 17.1
            {
                return "低体重"
            }
            else if bmiValue >= 24.0 && bmiValue <= 27.9
            {
                return "超重"
            }
            else
            {
                return "肥胖"
            }
        }
    }

    var bmiScore: Double
    {
        guard bmiValue > 0 else { return 0 }
        if gender == "男"
        {
            if (17.9 ... 23.9).contains(bmiValue) { return 100 }
            if (24.0 ... 27.9).contains(bmiValue) { return 80 }
            return 60 // < 17.9 或 > 27.9 都是 60
        }
        else
        {
            if (17.2 ... 23.9).contains(bmiValue) { return 100 }
            if (24.0 ... 27.9).contains(bmiValue) { return 80 }
            return 60
        }
    }

    private func getColor(level: String) -> Color
    {
        if level == "正常"
        {
            return .green
        }
        else if level == "低体重" || level == "超重"
        {
            return .orange
        }
        else if level == "肥胖"
        {
            return .red
        }
        else
        {
            return .secondary
        }
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            Text("BMI").font(.system(size: 15)).foregroundColor(.secondary)
            HStack
            {
                Spacer()
                if grade != "待输入"
                {
                    MiniScoreBadge(score: bmiScore)
                }
                else
                {
                    MiniScoreBadge(score: 0)
                }
                Spacer()
            }
            HStack
            {
                Text(bmiResult.isEmpty ? "自动计算" : bmiResult).font(.system(size: 18, weight: .bold)).foregroundColor(bmiResult.isEmpty ? .secondary : .primary)
                Spacer()
                Text(grade)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(getColor(level: grade))
                    .padding(5).background(getColor(level: grade).opacity(0.15)).clipShape(Capsule())
            }
        }
        .padding().background(RoundedRectangle(cornerRadius: 20).fill(Color(uiColor: .secondarySystemGroupedBackground)).shadow(color: .black.opacity(0.05), radius: 8))
    }
}

// MARK: - 评分表逻辑封装 (模拟图片中大三的标准)

struct ProjectStandard
{
    static func getGrade(from score: Double) -> String
    {
        switch score
        {
        case 90 ... 100: return "优秀"
        case 80 ..< 90: return "良好"
        case 60 ..< 80: return "及格"
        default: return "不及格"
        }
    }

    static func score(for project: String, value: Double, gender: String, gradeLevel: String) -> (Double, String)
    {
        let cur_gradeLevel = gradeLevel.suffix(1)
        var finalScore: Double = 0
        let isJuniorSenior = (cur_gradeLevel == "三" || cur_gradeLevel == "四" || cur_gradeLevel == "五")

        if gender == "男"
        {
            switch project
            {
            case "肺活量":
                if !isJuniorSenior
                { // 大一二
                    if value >= 5040 { finalScore = 100 } else if value >= 4920 { finalScore = 95 } else if value >= 4800 { finalScore = 90 } else if value >= 4550 { finalScore = 85 } else if value >= 4300 { finalScore = 80 } else if value >= 4180 { finalScore = 78 } else if value >= 4060 { finalScore = 76 } else if value >= 3940 { finalScore = 74 } else if value >= 3820 { finalScore = 72 } else if value >= 3700 { finalScore = 70 } else if value >= 3580 { finalScore = 68 } else if value >= 3460 { finalScore = 66 } else if value >= 3340 { finalScore = 64 } else if value >= 3220 { finalScore = 62 } else if value >= 3100 { finalScore = 60 } else if value >= 2940 { finalScore = 50 } else if value >= 2780 { finalScore = 40 } else if value >= 2620 { finalScore = 30 } else if value >= 2460 { finalScore = 20 } else if value >= 2300 { finalScore = 10 }
                }
                else
                { // 大三四
                    if value >= 5140 { finalScore = 100 } else if value >= 5020 { finalScore = 95 } else if value >= 4900 { finalScore = 90 } else if value >= 4650 { finalScore = 85 } else if value >= 4400 { finalScore = 80 } else if value >= 4280 { finalScore = 78 } else if value >= 4160 { finalScore = 76 } else if value >= 4040 { finalScore = 74 } else if value >= 3920 { finalScore = 72 } else if value >= 3800 { finalScore = 70 } else if value >= 3680 { finalScore = 68 } else if value >= 3560 { finalScore = 66 } else if value >= 3440 { finalScore = 64 } else if value >= 3320 { finalScore = 62 } else if value >= 3200 { finalScore = 60 } else if value >= 3030 { finalScore = 50 } else if value >= 2860 { finalScore = 40 } else if value >= 2690 { finalScore = 30 } else if value >= 2520 { finalScore = 20 } else if value >= 2350 { finalScore = 10 }
                }

            case "50米跑":
                if !isJuniorSenior
                {
                    if value <= 6.7 { finalScore = 100 } else if value <= 6.8 { finalScore = 95 } else if value <= 6.9 { finalScore = 90 } else if value <= 7.1 { finalScore = 85 } else if value <= 7.3 { finalScore = 80 } else if value <= 7.5 { finalScore = 78 } else if value <= 7.7 { finalScore = 76 } else if value <= 7.9 { finalScore = 74 } else if value <= 8.1 { finalScore = 72 } else if value <= 8.3 { finalScore = 70 } else if value <= 8.5 { finalScore = 68 } else if value <= 8.7 { finalScore = 66 } else if value <= 8.9 { finalScore = 64 } else if value <= 9.0 { finalScore = 62 } else if value <= 9.1 { finalScore = 60 } else if value <= 9.3 { finalScore = 50 } else if value <= 9.5 { finalScore = 40 } else if value <= 9.7 { finalScore = 30 } else if value <= 9.9 { finalScore = 20 } else if value <= 10.1 { finalScore = 10 }
                }
                else
                {
                    if value <= 6.6 { finalScore = 100 } else if value <= 6.7 { finalScore = 95 } else if value <= 6.8 { finalScore = 90 } else if value <= 7.0 { finalScore = 85 } else if value <= 7.2 { finalScore = 80 } else if value <= 7.4 { finalScore = 78 } else if value <= 7.6 { finalScore = 76 } else if value <= 7.8 { finalScore = 74 } else if value <= 8.0 { finalScore = 72 } else if value <= 8.2 { finalScore = 70 } else if value <= 8.4 { finalScore = 68 } else if value <= 8.6 { finalScore = 66 } else if value <= 8.8 { finalScore = 64 } else if value <= 8.9 { finalScore = 62 } else if value <= 9.0 { finalScore = 60 } else if value <= 9.2 { finalScore = 50 } else if value <= 9.4 { finalScore = 40 } else if value <= 9.6 { finalScore = 30 } else if value <= 9.8 { finalScore = 20 } else if value <= 10.0 { finalScore = 10 }
                }

            case "坐位体前屈":
                if !isJuniorSenior
                {
                    if value >= 24.9 { finalScore = 100 } else if value >= 23.1 { finalScore = 95 } else if value >= 21.3 { finalScore = 90 } else if value >= 19.5 { finalScore = 85 } else if value >= 17.7 { finalScore = 80 } else if value >= 16.3 { finalScore = 78 } else if value >= 14.9 { finalScore = 76 } else if value >= 13.5 { finalScore = 74 } else if value >= 12.1 { finalScore = 72 } else if value >= 10.7 { finalScore = 70 } else if value >= 9.3 { finalScore = 68 } else if value >= 7.9 { finalScore = 66 } else if value >= 6.5 { finalScore = 64 } else if value >= 5.1 { finalScore = 62 } else if value >= 3.7 { finalScore = 60 } else if value >= 2.7 { finalScore = 50 } else if value >= 1.7 { finalScore = 40 } else if value >= 0.7 { finalScore = 30 } else if value >= -0.3 { finalScore = 20 } else if value >= -1.3 { finalScore = 10 }
                }
                else
                {
                    if value >= 26.1 { finalScore = 100 } else if value >= 24.2 { finalScore = 95 } else if value >= 22.3 { finalScore = 90 } else if value >= 20.3 { finalScore = 85 } else if value >= 18.2 { finalScore = 80 } else if value >= 16.8 { finalScore = 78 } else if value >= 15.4 { finalScore = 76 } else if value >= 14.0 { finalScore = 74 } else if value >= 12.6 { finalScore = 72 } else if value >= 11.2 { finalScore = 70 } else if value >= 9.8 { finalScore = 68 } else if value >= 8.4 { finalScore = 66 } else if value >= 7.0 { finalScore = 64 } else if value >= 5.6 { finalScore = 62 } else if value >= 4.2 { finalScore = 60 } else if value >= 3.2 { finalScore = 50 } else if value >= 2.2 { finalScore = 40 } else if value >= 1.2 { finalScore = 30 } else if value >= 0.2 { finalScore = 20 } else if value >= -0.8 { finalScore = 10 }
                }

            case "立定跳远":
                if !isJuniorSenior
                {
                    if value >= 273 { finalScore = 100 } else if value >= 268 { finalScore = 95 } else if value >= 263 { finalScore = 90 } else if value >= 256 { finalScore = 85 } else if value >= 248 { finalScore = 80 } else if value >= 244 { finalScore = 78 } else if value >= 240 { finalScore = 76 } else if value >= 236 { finalScore = 74 } else if value >= 232 { finalScore = 72 } else if value >= 228 { finalScore = 70 } else if value >= 224 { finalScore = 68 } else if value >= 220 { finalScore = 66 } else if value >= 216 { finalScore = 64 } else if value >= 212 { finalScore = 62 } else if value >= 208 { finalScore = 60 } else if value >= 203 { finalScore = 50 } else if value >= 198 { finalScore = 40 } else if value >= 193 { finalScore = 30 } else if value >= 188 { finalScore = 20 } else if value >= 183 { finalScore = 10 }
                }
                else
                {
                    if value >= 275 { finalScore = 100 } else if value >= 270 { finalScore = 95 } else if value >= 265 { finalScore = 90 } else if value >= 258 { finalScore = 85 } else if value >= 250 { finalScore = 80 } else if value >= 246 { finalScore = 78 } else if value >= 242 { finalScore = 76 } else if value >= 238 { finalScore = 74 } else if value >= 234 { finalScore = 72 } else if value >= 230 { finalScore = 70 } else if value >= 226 { finalScore = 68 } else if value >= 222 { finalScore = 66 } else if value >= 218 { finalScore = 64 } else if value >= 214 { finalScore = 62 } else if value >= 210 { finalScore = 60 } else if value >= 205 { finalScore = 50 } else if value >= 200 { finalScore = 40 } else if value >= 195 { finalScore = 30 } else if value >= 190 { finalScore = 20 } else if value >= 185 { finalScore = 10 }
                }

            case "引体向上":
                if !isJuniorSenior
                {
                    if value >= 19 { finalScore = 100 } else if value >= 18 { finalScore = 95 } else if value >= 17 { finalScore = 90 } else if value >= 16 { finalScore = 85 } else if value >= 15 { finalScore = 80 } else if value >= 14 { finalScore = 76 } else if value >= 13 { finalScore = 72 } else if value >= 12 { finalScore = 68 } else if value >= 11 { finalScore = 64 } else if value >= 10 { finalScore = 60 } else if value >= 9 { finalScore = 50 } else if value >= 8 { finalScore = 40 } else if value >= 7 { finalScore = 30 } else if value >= 6 { finalScore = 20 } else if value >= 5 { finalScore = 10 }
                }
                else
                {
                    if value >= 20 { finalScore = 100 } else if value >= 19 { finalScore = 95 } else if value >= 18 { finalScore = 90 } else if value >= 17 { finalScore = 85 } else if value >= 16 { finalScore = 80 } else if value >= 15 { finalScore = 76 } else if value >= 14 { finalScore = 72 } else if value >= 13 { finalScore = 68 } else if value >= 12 { finalScore = 64 } else if value >= 11 { finalScore = 60 } else if value >= 10 { finalScore = 50 } else if value >= 9 { finalScore = 40 } else if value >= 8 { finalScore = 30 } else if value >= 7 { finalScore = 20 } else if value >= 6 { finalScore = 10 }
                }

            case "1000米跑":
                // 这里的输入应该是秒数，或者你在外层处理成秒
                if !isJuniorSenior
                {
                    if value <= 207 { finalScore = 100 } else if value <= 212 { finalScore = 95 } else if value <= 217 { finalScore = 90 } else if value <= 227 { finalScore = 85 } else if value <= 237 { finalScore = 80 } else if value <= 242 { finalScore = 78 } else if value <= 247 { finalScore = 76 } else if value <= 252 { finalScore = 74 } else if value <= 257 { finalScore = 72 } else if value <= 262 { finalScore = 70 } else if value <= 267 { finalScore = 68 } else if value <= 272 { finalScore = 66 } else if value <= 277 { finalScore = 64 } else if value <= 282 { finalScore = 62 } else if value <= 287 { finalScore = 60 } else if value <= 302 { finalScore = 50 } else if value <= 317 { finalScore = 40 } else if value <= 332 { finalScore = 30 } else if value <= 347 { finalScore = 20 } else if value <= 362 { finalScore = 10 }
                }
                else
                {
                    if value <= 210 { finalScore = 100 } else if value <= 215 { finalScore = 95 } else if value <= 220 { finalScore = 90 } else if value <= 230 { finalScore = 85 } else if value <= 240 { finalScore = 80 } else if value <= 245 { finalScore = 78 } else if value <= 250 { finalScore = 76 } else if value <= 255 { finalScore = 74 } else if value <= 260 { finalScore = 72 } else if value <= 265 { finalScore = 70 } else if value <= 270 { finalScore = 68 } else if value <= 275 { finalScore = 66 } else if value <= 280 { finalScore = 64 } else if value <= 285 { finalScore = 62 } else if value <= 290 { finalScore = 60 } else if value <= 305 { finalScore = 50 } else if value <= 320 { finalScore = 40 } else if value <= 335 { finalScore = 30 } else if value <= 350 { finalScore = 20 } else if value <= 365 { finalScore = 10 }
                }

            default: break
            }
        }
        else // 女生逻辑
        {
            switch project
            {
            case "肺活量":
                if !isJuniorSenior
                { // 大一二
                    if value >= 3400 { finalScore = 100 } else if value >= 3350 { finalScore = 95 } else if value >= 3300 { finalScore = 90 } else if value >= 3150 { finalScore = 85 } else if value >= 3000 { finalScore = 80 } else if value >= 2900 { finalScore = 78 } else if value >= 2800 { finalScore = 76 } else if value >= 2700 { finalScore = 74 } else if value >= 2600 { finalScore = 72 } else if value >= 2500 { finalScore = 70 } else if value >= 2400 { finalScore = 68 } else if value >= 2300 { finalScore = 66 } else if value >= 2200 { finalScore = 64 } else if value >= 2100 { finalScore = 62 } else if value >= 2000 { finalScore = 60 } else if value >= 1960 { finalScore = 50 } else if value >= 1920 { finalScore = 40 } else if value >= 1880 { finalScore = 30 } else if value >= 1840 { finalScore = 20 } else if value >= 1800 { finalScore = 10 }
                }
                else
                { // 大三四
                    if value >= 3450 { finalScore = 100 } else if value >= 3400 { finalScore = 95 } else if value >= 3350 { finalScore = 90 } else if value >= 3200 { finalScore = 85 } else if value >= 3050 { finalScore = 80 } else if value >= 2950 { finalScore = 78 } else if value >= 2850 { finalScore = 76 } else if value >= 2750 { finalScore = 74 } else if value >= 2650 { finalScore = 72 } else if value >= 2550 { finalScore = 70 } else if value >= 2450 { finalScore = 68 } else if value >= 2350 { finalScore = 66 } else if value >= 2250 { finalScore = 64 } else if value >= 2150 { finalScore = 62 } else if value >= 2050 { finalScore = 60 } else if value >= 2010 { finalScore = 50 } else if value >= 1970 { finalScore = 40 } else if value >= 1930 { finalScore = 30 } else if value >= 1890 { finalScore = 20 } else if value >= 1850 { finalScore = 10 }
                }

            case "50米跑":
                if !isJuniorSenior
                {
                    if value <= 7.5 { finalScore = 100 } else if value <= 7.6 { finalScore = 95 } else if value <= 7.7 { finalScore = 90 } else if value <= 8.0 { finalScore = 85 } else if value <= 8.3 { finalScore = 80 } else if value <= 8.5 { finalScore = 78 } else if value <= 8.7 { finalScore = 76 } else if value <= 8.9 { finalScore = 74 } else if value <= 9.1 { finalScore = 72 } else if value <= 9.3 { finalScore = 70 } else if value <= 9.5 { finalScore = 68 } else if value <= 9.7 { finalScore = 66 } else if value <= 9.9 { finalScore = 64 } else if value <= 10.1 { finalScore = 62 } else if value <= 10.3 { finalScore = 60 } else if value <= 10.5 { finalScore = 50 } else if value <= 10.7 { finalScore = 40 } else if value <= 10.9 { finalScore = 30 } else if value <= 11.1 { finalScore = 20 } else if value <= 11.3 { finalScore = 10 }
                }
                else
                {
                    if value <= 7.4 { finalScore = 100 } else if value <= 7.5 { finalScore = 95 } else if value <= 7.6 { finalScore = 90 } else if value <= 7.9 { finalScore = 85 } else if value <= 8.2 { finalScore = 80 } else if value <= 8.4 { finalScore = 78 } else if value <= 8.6 { finalScore = 76 } else if value <= 8.8 { finalScore = 74 } else if value <= 9.0 { finalScore = 72 } else if value <= 9.2 { finalScore = 70 } else if value <= 9.4 { finalScore = 68 } else if value <= 9.6 { finalScore = 66 } else if value <= 9.8 { finalScore = 64 } else if value <= 10.0 { finalScore = 62 } else if value <= 10.2 { finalScore = 60 } else if value <= 10.4 { finalScore = 50 } else if value <= 10.6 { finalScore = 40 } else if value <= 10.8 { finalScore = 30 } else if value <= 11.0 { finalScore = 20 } else if value <= 11.2 { finalScore = 10 }
                }

            case "坐位体前屈":
                if !isJuniorSenior
                {
                    if value >= 26.3 { finalScore = 100 } else if value >= 24.1 { finalScore = 95 } else if value >= 21.9 { finalScore = 90 } else if value >= 19.5 { finalScore = 85 } else if value >= 17.2 { finalScore = 80 } else if value >= 15.6 { finalScore = 78 } else if value >= 14.1 { finalScore = 76 } else if value >= 12.6 { finalScore = 74 } else if value >= 11.1 { finalScore = 72 } else if value >= 9.6 { finalScore = 70 } else if value >= 8.1 { finalScore = 68 } else if value >= 6.6 { finalScore = 66 } else if value >= 5.1 { finalScore = 64 } else if value >= 3.6 { finalScore = 62 } else if value >= 2.1 { finalScore = 60 } else if value >= 1.1 { finalScore = 50 } else if value >= 0.1 { finalScore = 40 } else if value >= -0.9 { finalScore = 30 } else if value >= -1.9 { finalScore = 20 } else if value >= -2.9 { finalScore = 10 }
                }
                else
                {
                    if value >= 27.0 { finalScore = 100 } else if value >= 24.8 { finalScore = 95 } else if value >= 22.6 { finalScore = 90 } else if value >= 20.1 { finalScore = 85 } else if value >= 17.7 { finalScore = 80 } else if value >= 16.1 { finalScore = 78 } else if value >= 14.6 { finalScore = 76 } else if value >= 13.1 { finalScore = 74 } else if value >= 11.6 { finalScore = 72 } else if value >= 10.1 { finalScore = 70 } else if value >= 8.6 { finalScore = 68 } else if value >= 7.1 { finalScore = 66 } else if value >= 5.6 { finalScore = 64 } else if value >= 4.1 { finalScore = 62 } else if value >= 2.6 { finalScore = 60 } else if value >= 1.6 { finalScore = 50 } else if value >= 0.6 { finalScore = 40 } else if value >= -0.4 { finalScore = 30 } else if value >= -1.4 { finalScore = 20 } else if value >= -2.4 { finalScore = 10 }
                }

            case "立定跳远":
                if !isJuniorSenior
                {
                    if value >= 207 { finalScore = 100 } else if value >= 201 { finalScore = 95 } else if value >= 195 { finalScore = 90 } else if value >= 188 { finalScore = 85 } else if value >= 181 { finalScore = 80 } else if value >= 178 { finalScore = 78 } else if value >= 175 { finalScore = 76 } else if value >= 172 { finalScore = 74 } else if value >= 169 { finalScore = 72 } else if value >= 166 { finalScore = 70 } else if value >= 163 { finalScore = 68 } else if value >= 160 { finalScore = 66 } else if value >= 157 { finalScore = 64 } else if value >= 154 { finalScore = 62 } else if value >= 151 { finalScore = 60 } else if value >= 146 { finalScore = 50 } else if value >= 141 { finalScore = 40 } else if value >= 136 { finalScore = 30 } else if value >= 131 { finalScore = 20 } else if value >= 126 { finalScore = 10 }
                }
                else
                {
                    if value >= 208 { finalScore = 100 } else if value >= 202 { finalScore = 95 } else if value >= 196 { finalScore = 90 } else if value >= 189 { finalScore = 85 } else if value >= 182 { finalScore = 80 } else if value >= 179 { finalScore = 78 } else if value >= 176 { finalScore = 76 } else if value >= 173 { finalScore = 74 } else if value >= 170 { finalScore = 72 } else if value >= 167 { finalScore = 70 } else if value >= 164 { finalScore = 68 } else if value >= 161 { finalScore = 66 } else if value >= 158 { finalScore = 64 } else if value >= 155 { finalScore = 62 } else if value >= 152 { finalScore = 60 } else if value >= 147 { finalScore = 50 } else if value >= 142 { finalScore = 40 } else if value >= 137 { finalScore = 30 } else if value >= 132 { finalScore = 20 } else if value >= 127 { finalScore = 10 }
                }

            case "仰卧起坐":
                if !isJuniorSenior
                {
                    if value >= 56 { finalScore = 100 } else if value >= 54 { finalScore = 95 } else if value >= 52 { finalScore = 90 } else if value >= 49 { finalScore = 85 } else if value >= 46 { finalScore = 80 } else if value >= 44 { finalScore = 78 } else if value >= 42 { finalScore = 76 } else if value >= 40 { finalScore = 74 } else if value >= 38 { finalScore = 72 } else if value >= 36 { finalScore = 70 } else if value >= 34 { finalScore = 68 } else if value >= 32 { finalScore = 66 } else if value >= 30 { finalScore = 64 } else if value >= 28 { finalScore = 62 } else if value >= 26 { finalScore = 60 } else if value >= 24 { finalScore = 50 } else if value >= 22 { finalScore = 40 } else if value >= 20 { finalScore = 30 } else if value >= 18 { finalScore = 20 } else if value >= 16 { finalScore = 10 }
                }
                else
                {
                    if value >= 57 { finalScore = 100 } else if value >= 55 { finalScore = 95 } else if value >= 53 { finalScore = 90 } else if value >= 50 { finalScore = 85 } else if value >= 47 { finalScore = 80 } else if value >= 45 { finalScore = 78 } else if value >= 43 { finalScore = 76 } else if value >= 41 { finalScore = 74 } else if value >= 39 { finalScore = 72 } else if value >= 37 { finalScore = 70 } else if value >= 35 { finalScore = 68 } else if value >= 33 { finalScore = 66 } else if value >= 31 { finalScore = 64 } else if value >= 29 { finalScore = 62 } else if value >= 27 { finalScore = 60 } else if value >= 25 { finalScore = 50 } else if value >= 23 { finalScore = 40 } else if value >= 21 { finalScore = 30 } else if value >= 19 { finalScore = 20 } else if value >= 17 { finalScore = 10 }
                }

            case "800米跑":
                if !isJuniorSenior
                {
                    if value <= 198 { finalScore = 100 } else if value <= 204 { finalScore = 95 } else if value <= 210 { finalScore = 90 } else if value <= 217 { finalScore = 85 } else if value <= 224 { finalScore = 80 } else if value <= 229 { finalScore = 78 } else if value <= 234 { finalScore = 76 } else if value <= 239 { finalScore = 74 } else if value <= 244 { finalScore = 72 } else if value <= 249 { finalScore = 70 } else if value <= 254 { finalScore = 68 } else if value <= 259 { finalScore = 66 } else if value <= 264 { finalScore = 64 } else if value <= 269 { finalScore = 62 } else if value <= 274 { finalScore = 60 } else if value <= 284 { finalScore = 50 } else if value <= 294 { finalScore = 40 } else if value <= 304 { finalScore = 30 } else if value <= 314 { finalScore = 20 } else if value <= 324 { finalScore = 10 }
                }
                else
                {
                    if value <= 200 { finalScore = 100 } else if value <= 206 { finalScore = 95 } else if value <= 212 { finalScore = 90 } else if value <= 219 { finalScore = 85 } else if value <= 226 { finalScore = 80 } else if value <= 231 { finalScore = 78 } else if value <= 236 { finalScore = 76 } else if value <= 241 { finalScore = 74 } else if value <= 246 { finalScore = 72 } else if value <= 251 { finalScore = 70 } else if value <= 256 { finalScore = 68 } else if value <= 261 { finalScore = 66 } else if value <= 266 { finalScore = 64 } else if value <= 271 { finalScore = 62 } else if value <= 276 { finalScore = 60 } else if value <= 286 { finalScore = 50 } else if value <= 296 { finalScore = 40 } else if value <= 306 { finalScore = 30 } else if value <= 316 { finalScore = 20 } else if value <= 326 { finalScore = 10 }
                }

            default: break
            }
        }

        return (finalScore, getGrade(from: finalScore))
    }

    static func totalGrade(score: Double) -> String
    {
        if score >= 90 { return "优秀" }
        if score >= 80 { return "良好" }
        if score >= 60 { return "及格" }
        return "不及格"
    }
}

// MARK: - 保存按钮

struct SaveScoreButton: View
{
    @Binding var showFeedback: Bool
    @Binding var showPicker: Bool
    let selectedYear: String
    var onSave: () -> Void

    var body: some View
    {
        HStack(spacing: 16)
        {
            // 学年选择按钮
            Button(action: { showPicker = true })
            {
                HStack(spacing: 6)
                {
                    Image(systemName: "calendar")
                    Text(selectedYear)
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .clipShape(Capsule())
            }
            .optionalLiquidGlass()

            // 保存按钮
            Button(action: { onSave() })
            {
                HStack(spacing: 8)
                {
                    if showFeedback
                    {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                        Text("已保存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .transition(.opacity)
                    }
                    else
                    {
                        Text("保存成绩")
                            .font(.headline)
                            .foregroundColor(.white)
                            .transition(.opacity)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 25)
                .background(showFeedback ? Color.green : Color.blue)
                .clipShape(Capsule())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showFeedback)
            }
            .optionalLiquidGlass()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .glassBackground(cornerRadius: 64)
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
}

#Preview
{
    NavigationView { PhysicalTestCalculatorView() }
}
