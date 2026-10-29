import SwiftUI

struct CourseCard: View
{
    let course: ITC_Course

    // 根据课程名哈希分配一个固定的色调
    private var cardColor: Color
    {
        let palette: [Color] = [
            .blue, .purple, .pink, .orange, .teal, .green, .indigo, .cyan
        ]
        let idx = abs(course.courseID.hashValue) % palette.count
        return palette[idx]
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 8)
        {
            // 课程图标
            ZStack
            {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cardColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(cardColor)
            }

            Spacer()

            Text(course.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(cardColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var iconName: String
    {
        let name = course.name
        if name.contains("程序") || name.contains("编程") || name.contains("C语言") || name.contains("Python") || name.contains("Java") || name.contains("JAVA") { return "chevron.left.forwardslash.chevron.right" }
        if name.contains("数学") || name.contains("算法") || name.contains("数据结构") { return "function" }
        if name.contains("网络") { return "network" }
        if name.contains("操作系统") { return "cpu" }
        if name.contains("数字") || name.contains("逻辑") || name.contains("EDA") { return "waveform" }
        if name.contains("图像") || name.contains("图形") || name.contains("多媒体") { return "photo" }
        if name.contains("神经") || name.contains("深度") || name.contains("AI") || name.contains("人工智能") { return "brain.head.profile" }
        if name.contains("物联") { return "antenna.radiowaves.left.and.right" }
        if name.contains("编译") { return "doc.text.magnifyingglass" }
        if name.contains("嵌入") { return "memorychip" }
        if name.contains("组成原理") { return "memorychip" }
        return "book.closed.fill"
    }
}

#Preview {
    ITCView().environmentObject(userInfo())
}
