// 全校课程查询列表的局部卡片与标签。

import SwiftUI

struct AllCourseCardRow: View
{
    let course: CourseInfo

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            HStack(alignment: .top)
            {
                Text(course.kcmc)
                    .font(.system(size: 18, weight: .bold))
                    .textSelection(.enabled)
                Spacer()
                if let displayCode = course.displayCode
                {
                    Text(displayCode)
                        .font(.caption)
                        .monospacedDigit()
                        .padding(4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                        .textSelection(.enabled)
                }
            }

            VStack(alignment: .leading, spacing: 8)
            {
                HStack(spacing: 5)
                {
                    Image(systemName: "graduationcap.circle.fill")
                        .foregroundColor(.blue)
                    Text(course.kkbmmc ?? course.teacherName ?? "未知信息")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }

                if course.querySource == .shishanyouni
                {
                    if let siteName = course.siteName, !siteName.isEmpty
                    {
                        HStack(spacing: 5)
                        {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.orange)
                            Text(siteName)
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                HStack(spacing: 8)
                {
                    if let category = course.kclbmc
                    {
                        TagView(text: category, color: .orange)
                    }
                    if let nature = course.kcxzmc
                    {
                        TagView(text: nature, color: .green)
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
    }
}

struct TagView: View
{
    let text: String
    let color: Color

    var body: some View
    {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.5))
    }
}

#Preview
{
    AllCourseView()
        .environmentObject(userInfo())
}
