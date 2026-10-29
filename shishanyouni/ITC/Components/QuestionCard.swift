import SwiftUI

struct QuestionCard: View
{
    let question: ITC_Question
    var index: Int = 0   // 区块内序号，0 = 不显示

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            HStack(alignment: .top)
            {
                if index > 0
                {
                    Text("\(index).")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 24, alignment: .leading)
                }
                Text(question.name)
                    .font(.body)
                    .fontWeight(.semibold)
                Spacer()
                if question.grade != "-"
                {
                    Text("\(question.grade) / \(question.questionFullGrade)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(gradeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(gradeColor.opacity(0.1))
                        .cornerRadius(6)
                }
                else if question.hasSubmitted
                {
                    Text("已提交")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
                else if question.questionFullGrade != "-"
                {
                    Text("- / \(question.questionFullGrade)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            if question.grade == "-" && question.hasSubmitted
            {
                HStack(spacing: 16)
                {
                    if question.firstSubmitTime != "-"
                    {
                        Label("初次: \(question.firstSubmitTime)", systemImage: "arrow.up.doc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if question.lastUpdate != "-"
                    {
                        Label("最近: \(question.lastUpdate)", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            else
            {
                if question.lastUpdate != "-"
                {
                    Label(question.lastUpdate, systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !question.testData.isEmpty
            {
                Divider()
                Text("测试数据")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(question.testData) { td in
                    HStack
                    {
                        Text(td.dataID)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(td.correctStatus)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(td.isCorrect ? .green : .red)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var gradeColor: Color
    {
        guard let g = Double(question.grade), let f = Double(question.questionFullGrade), f > 0 else { return .secondary }
        let ratio = g / f
        if ratio >= 1.0 { return .green }
        if ratio >= 0.6 { return .orange }
        return .red
    }
}
