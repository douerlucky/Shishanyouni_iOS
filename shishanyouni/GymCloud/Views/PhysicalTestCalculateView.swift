import SwiftUI

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
                VStack(alignment: .leading, spacing: physicalTestCalcSectionSpacing)
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
                    .padding(physicalTestCalcCardInnerPadding)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, physicalTestCalcCardHorizontalPadding)

                    VStack(alignment: .leading, spacing: 6)
                    {
                        Text("本功能仅用于参考，不构成任何医疗或健康建议")
                            .font(.system(size: 14))
                        Text("数据来源：\(physicalTestCitationTitle)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.8))
                        Text("其中 BMI 分类与分值计算同样依据该标准执行。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.8))
                        Link("查看官方标准说明", destination: physicalTestCitationURL)
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(physicalTestCalcCardInnerPadding)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, physicalTestCalcCardHorizontalPadding)

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
                    .padding(physicalTestCalcCardInnerPadding)
                    .background(RoundedRectangle(cornerRadius: 15).fill(Color(uiColor: .secondarySystemGroupedBackground)))
                    .padding(.horizontal, physicalTestCalcCardHorizontalPadding)

                    // MARK: 3. 单项成绩网格

                    VStack(alignment: .leading, spacing: 16)
                    {
                        Text("单项成绩").font(.title2.bold()).padding(.horizontal, physicalTestCalcCardHorizontalPadding)

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
                            CalcBMICard(bmiValue: bmiValue, bmiResult: bmiResult, gender: gender)
                                .padding(.horizontal, physicalTestCalcCardHorizontalPadding)

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
                                            EmptyView()
                                        }
                                        else
                                        {
                                            CalcDetailCard(detail: $detail) { calculateScore() }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, physicalTestCalcCardHorizontalPadding)
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
            AcceptButton("确定") { showPicker = false }.padding()
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
