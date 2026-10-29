import SwiftUI
import UIKit
import Photos

/// 用于 ImageRenderer 的完整成绩内容。
///
/// 屏幕上的成绩页使用 ScrollView + LazyVGrid；导出时使用普通 VStack 和 HStack，
/// 让所有成绩卡片都参与布局，同时保持页面上的两列布局。
struct GradeExportView: View
{
    let grades: [Grade]

    var body: some View
    {
        VStack(alignment: .leading, spacing: 20)
        {
            Text("成绩查询")
                .font(.largeTitle.bold())
                .padding(.horizontal, 16)

            GradeSummaryCard(
                includedGrades: grades,
                allGrades: grades
            )

            Text("单科成绩")
                .font(.title2.bold())
                .padding(.horizontal, 16)

            // 使用普通 VStack + HStack，确保长图包含全部课程，并保持两列布局。
            VStack(spacing: 14)
            {
                ForEach(Array(stride(from: 0, to: grades.count, by: 2)), id: \.self)
                { index in
                    HStack(alignment: .top, spacing: 14)
                    {
                        GradeCard(
                            grade: grades[index],
                            included: .constant(true)
                        )
                        // 导出结果是静态图片，不需要响应卡片中的勾选按钮。
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, alignment: .top)

                        if index + 1 < grades.count
                        {
                            GradeCard(
                                grade: grades[index + 1],
                                included: .constant(true)
                            )
                            .allowsHitTesting(false)
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                        else
                        {
                            // 奇数门课程时保留右侧空位，避免最后一张卡片变成整行宽度。
                            Color.clear
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
        .frame(width: UIScreen.main.bounds.width)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
