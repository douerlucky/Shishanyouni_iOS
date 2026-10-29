// “我的”页面专用设置入口行。

import SwiftUI

struct ProfileSettingRow: View
{
    let title: String
    let icon: String
    let color: Color
    var showsChevron = false

    var body: some View
    {
        HStack(spacing: 15)
        {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background
                {
                    RoundedRectangle(cornerRadius: 6).fill(color)
                        .componentBackgroundOpacity()
                }

            Text(title)
                .foregroundStyle(.primary)
                .appTextOpacity()

            Spacer(minLength: 0)

            if showsChevron
            {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
