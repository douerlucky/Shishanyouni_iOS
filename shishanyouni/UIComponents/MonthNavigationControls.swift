import SwiftUI

/// 日程和校历共用原生月份操作，不分别绘制箭头底色与玻璃。
struct MonthNavigationControls: View
{
    var tint: Color = appActionBlue
    let onPrevious: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void

    var body: some View
    {
        HStack
        {
            NextButton(systemImage: "chevron.left", tint: tint, size: 36, action: onPrevious)
                .accessibilityLabel("上个月")
            Spacer()
            Button(action: onToday)
            {
                Text("今天").appTextOpacity()
            }
                .nativeGlassButtonStyle()
                .tint(tint)
            Spacer()
            NextButton(systemImage: "chevron.right", tint: tint, size: 36, action: onNext)
                .accessibilityLabel("下个月")
        }
    }
}
