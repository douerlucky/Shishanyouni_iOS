import SwiftUI

// MARK: - 教学班分组卡片视图

struct ClassGroupCard: View
{
    let jxbmc: String
    let infos: [CourseClassInfo]
    let showHeader: Bool
    let onAddToSchedule: ([CourseClassInfo]) -> Void

    var body: some View
    {
        VStack(alignment: .leading, spacing: 0)
        {
            // Header: 教学班名称和选课人数
            if showHeader
            {
                HStack
                {
                    Text(jxbmc)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.05))
            }

            HStack(alignment: .center, spacing: 12)
            {
                VStack(alignment: .leading, spacing: 8)
                {
                    // 教师信息
                    if let teacher = infos.first?.xm
                    {
                        HStack(spacing: 8)
                        {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            Text(teacher)
                                .font(.system(size: 16, weight: .medium))
                            if let title = infos.first?.zcmc
                            {
                                Text(title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // 开课班级
                    if let composition = infos.first?.jxbzc
                    {
                        HStack(spacing: 6)
                        {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10, weight: .bold))

                            Text(composition)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundColor(.secondary)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: { onAddToSchedule(infos) })
                {
                    Label("添加到课表", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .nativeGlassButtonStyle(prominent: true)
                .tint(appActionBlue)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // 具体安排列表
            VStack(alignment: .leading, spacing: 8)
            {
                ForEach(infos)
                { info in
                    HStack(alignment: .top, spacing: 8)
                    {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 2)
                        {
                            Text("\(info.xqjmc ?? "") \(info.jc ?? "")")
                                .font(.system(size: 14, weight: .semibold))

                            HStack(spacing: 10)
                            {
                                Label(info.cdmc ?? "未知地点", systemImage: "mappin.and.ellipse")
                                Label(info.zcd ?? "未知周次", systemImage: "calendar.badge.clock")
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 15)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
