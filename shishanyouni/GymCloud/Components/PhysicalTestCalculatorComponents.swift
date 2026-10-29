import SwiftUI

let physicalTestCitationTitle = "《国家学生体质健康标准（2014年修订）》"
let physicalTestCitationURL = URL(string: "http://www.moe.gov.cn/s78/A17/twys_left/moe_938/moe_792/s3273/201407/t20140708_171692.html")!
let physicalTestCalcSectionSpacing: CGFloat = 20
let physicalTestCalcCardHorizontalPadding: CGFloat = 16
let physicalTestCalcCardInnerPadding: CGFloat = 16

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
        VStack(alignment: .leading, spacing: 12)
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
        .padding(physicalTestCalcCardInnerPadding)
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
        HStack(alignment: .top, spacing: 20)
        {
            VStack(alignment: .leading, spacing: 12)
            {
                Text("身体形态 (BMI)")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

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
                    Text(bmiResult.isEmpty ? "自动计算" : bmiResult)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(bmiResult.isEmpty ? .secondary : .primary)
                    Spacer()
                    Text(grade)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(getColor(level: grade))
                        .padding(5)
                        .background(getColor(level: grade).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6)
            {
                Text("BMI 信息依据：\(physicalTestCitationTitle)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Link("查看 BMI 官方标准说明", destination: physicalTestCitationURL)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        }
        .padding(physicalTestCalcCardInnerPadding)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(uiColor: .secondarySystemGroupedBackground)).shadow(color: .black.opacity(0.05), radius: 8))
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
            SemesterSelector(title: selectedYear, action: { showPicker = true })
            LiquidGlassCapsuleButton(
                title: showFeedback ? "已保存" : "保存成绩",
                tint: showFeedback ? .green : appActionBlue,
                action: onSave
            )
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
