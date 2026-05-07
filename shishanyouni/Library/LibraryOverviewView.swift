import SwiftUI

struct LibraryOverviewView: View
{
    @EnvironmentObject var userinfo: userInfo
    @State private var stats: LibrarySeatStats?
    @State private var isLoading = true
    @State private var navigateToReserve = false

    var body: some View
    {
        ScrollView
        {
            VStack(spacing: 20)
            {
                statsCard

                reservationRulesCard

                Button(action: { navigateToReserve = true })
                {
                    HStack(spacing: 8)
                    {
                        Image(systemName: "chair.lounge.fill")
                            .font(.system(size: 18))
                        Text("开始预约座位")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AdaptiveColors.libraryGreen1, AdaptiveColors.libraryGreen2],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("图书馆座位预约")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $navigateToReserve)
        {
            LibraryFlowView()
                .environmentObject(userinfo)
        }
        .task { await loadStats() }
    }

    private var statsCard: some View
    {
        VStack(spacing: 16)
        {
            HStack
            {
                Image(systemName: "building.columns.fill")
                    .font(.title2)
                    .foregroundColor(AdaptiveColors.statGreen)
                Text("实时座位状态")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                if isLoading
                {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                else
                {
                    Button(action: { Task { await loadStats() } })
                    {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let s = stats
            {
                HStack(spacing: 12)
                {
                    StatItem(
                        value: "\(s.available)",
                        label: "当前可用",
                        color: AdaptiveColors.libraryStatGreen
                    )
                    StatItem(
                        value: "\(s.inUse)",
                        label: "已使用",
                        color: AdaptiveColors.statBlue
                    )
                    StatItem(
                        value: "\(s.notSignedIn)",
                        label: "未签到",
                        color: AdaptiveColors.statOrange
                    )
                }
            }
            else if !isLoading
            {
                Text("加载失败，下拉刷新")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    private var reservationRulesCard: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            HStack
            {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("预约规则")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8)
            {
                RuleRow(icon: "clock", text: "当日预约：06:00 - 23:00")
                RuleRow(icon: "clock.badge", text: "次日预约：22:00 - 23:00")
                RuleRow(icon: "repeat", text: "每天最多预约 3 次")
                RuleRow(icon: "timer", text: "每次 30 分钟 - 15 小时")
                RuleRow(icon: "xmark.circle", text: "取消预约：生效前 15 分钟")
                RuleRow(icon: "person.badge.shield.checkmark", text: "签到：预约时间后 30 分钟内")
                RuleRow(icon: "figure.walk.departure", text: "暂离：30 分钟（用餐时段 90 分钟）")
                RuleRow(icon: "exclamationmark.triangle", text: "违约 7 次 → 黑名单 7 天")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    private func loadStats() async
    {
        isLoading = true
        do
        {
            stats = try await LibraryService.shared.fetchStats()
        }
        catch
        {
            stats = nil
        }
        isLoading = false
    }
}

private struct StatItem: View
{
    let value: String
    let label: String
    let color: Color

    var body: some View
    {
        VStack(spacing: 6)
        {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct RuleRow: View
{
    let icon: String
    let text: String

    var body: some View
    {
        HStack(spacing: 8)
        {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

#Preview
{
    NavigationStack
    {
        LibraryOverviewView()
            .environmentObject(userInfo())
    }
}
