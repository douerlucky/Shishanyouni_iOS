import SwiftUI

struct ElectricityBindingButton: View
{
    var prepareBinding: () -> Void

    @Binding var savedRoomId: String

    var body: some View
    {
        HStack(spacing: 20)
        {
            LiquidGlassCapsuleButton(
                title: savedRoomId.isEmpty ? "绑定房间" : "重新绑定",
                tint: savedRoomId.isEmpty ? appActionBlue : .red,
                action: prepareBinding
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .glassBackground(cornerRadius: 64)
        .padding(.horizontal, 20)
        .padding(.bottom, 30) // 距离底部安全区域的距离
    }
}

#Preview
{
    ElectricityView()
        .environmentObject(userInfo())
}
