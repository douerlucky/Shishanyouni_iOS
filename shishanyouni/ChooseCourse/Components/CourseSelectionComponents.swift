import SwiftUI
import UIKit

/// 选课相关网络流程的统一居中提示。透明命中层会在请求期间挡住重复点击，
/// 但不额外加深整页颜色，仍保持系统分组背景的层次。
struct CourseCenteredLoadingOverlay: View
{
    let message: String

    var body: some View
    {
        ZStack
        {
            Color.black.opacity(0.001)
                .ignoresSafeArea()

            VStack(spacing: 13)
            {
                ProgressView()
                    .controlSize(.large)
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 280)
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay
            {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

/// 当一门课程返回多个主教学班时，先让用户选定主班，再继续原有子班流程。
struct ParentCoursePickerSheet: View
{
    let course: CourseSearchResult
    let parentClasses: [CourseSearchResult]
    let onSelect: (CourseSearchResult) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View
    {
        NavigationStack
        {
            List(parentClasses)
            { parentClass in
                Button
                {
                    onSelect(parentClass)
                } label: {
                    HStack(spacing: 12)
                    {
                        VStack(alignment: .leading, spacing: 5)
                        {
                            Text(parentClass.teachingClassName.ifEmpty("教学班"))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(parentClass.requiresChildClass ? "选择后还需选择子教学班" : "可直接选课")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("选择教学班")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .topBarLeading)
                {
                    Button("取消", action: dismiss.callAsFunction)
                }
            }
            .safeAreaInset(edge: .top)
            {
                Text(course.displayTitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct ChildCoursePickerSheet: View
{
    let course: CourseSearchResult
    let childClasses: [CourseChildClass]
    let onSelect: (CourseChildClass) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View
    {
        NavigationStack
        {
            ScrollView
            {
                LazyVStack(alignment: .leading, spacing: 14)
                {
                    VStack(alignment: .leading, spacing: 5)
                    {
                        Text("主课程")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(course.courseName)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.bottom, 4)

                    ForEach(childClasses)
                    { childClass in
                        ChildClassSelectionCard(
                            childClass: childClass,
                            onSelect: { onSelect(childClass) }
                        )
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("选择子教学班")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .topBarLeading)
                {
                    Button("取消", action: dismiss.callAsFunction)
                }
            }
        }
        // 不使用 clear / material 背景：这是标准不透明 Sheet，避免后面的目录颜色透进来。
        .presentationDetents([.large])
    }
}

/// 子教学班使用深灰色的实体卡片与白字，和父页面的中性灰层级区分开；
/// 容量固定紧跟教学班标题，底部按钮只保留“选课”这个动作词。
private struct ChildClassSelectionCard: View
{
    let childClass: CourseChildClass
    let onSelect: () -> Void

    private var capacityStatus: CourseCapacityStatus { childClass.capacityStatus }
    /// 第一轮等阶段可能不限容量，甚至会出现已选人数大于容量的显示。
    /// 容量只负责提示；只要教务返回了有效 token，就允许把一次请求交给服务器裁决。
    private var canSelect: Bool { childClass.canSelect }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 11)
        {
            Text(childClass.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text(capacityStatus.availabilityText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(capacityStatus.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(capacityStatus.tint.opacity(0.20), in: Capsule())

            if childClass.teacher != "--"
            {
                Label(childClass.teacher, systemImage: "person.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
            }
            if childClass.schedule != "--"
            {
                Label(childClass.schedule, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if childClass.location != "--"
            {
                Label(childClass.location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onSelect)
            {
                Text("选课")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .nativeGlassButtonStyle(prominent: true, fillsWidth: true, backgroundTint: capacityStatus.tint)
            .tint(capacityStatus.tint)
            .controlSize(.large)
            .disabled(!canSelect)
            .accessibilityLabel("选课")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .darkGray), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
