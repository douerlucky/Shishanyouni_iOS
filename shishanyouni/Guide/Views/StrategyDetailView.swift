import SwiftUI
import WebKit

// MARK: - 详情主视图

struct StrategyDetailView: View
{
    let guideId: Int
    @StateObject private var viewModel = StrategyDetailViewModel()
    @State private var webHeight: CGFloat = 300

    var body: some View
    {
        ScrollView
        {
            if viewModel.isLoading
            {
                VStack(spacing: 16)
                {
                    ProgressView().scaleEffect(1.4)
                    Text("加载中...").foregroundColor(.secondary).font(.subheadline)
                }
                .frame(maxWidth: .infinity).padding(.top, 100)
            }
            else if let error = viewModel.errorMessage
            {
                VStack(spacing: 16)
                {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 48)).foregroundColor(.secondary)
                    Text(error).foregroundColor(.secondary).font(.subheadline)
                        .multilineTextAlignment(.center).padding(.horizontal)
                    Button("重新加载") { viewModel.fetchDetail(id: guideId) }.nativeGlassButtonStyle(prominent: true)
                }
                .frame(maxWidth: .infinity).padding(.top, 100)
            }
            else if let guide = viewModel.guide
            {
                VStack(alignment: .leading, spacing: 0)
                {
                    // 头部
                    HStack(spacing: 16)
                    {
                        AsyncImage(url: URL(string: guide.icon ?? ""))
                        { phase in
                            switch phase
                            {
                            case let .success(img): img.resizable().scaledToFit()
                            case .failure: Image(systemName: "photo").resizable().scaledToFit().foregroundColor(.gray)
                            default: ProgressView()
                            }
                        }
                        .frame(width: 48, height: 48)
                        .padding(16)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 5)
                        {
                            Text(guide.name).font(.title2).fontWeight(.bold)
                            if let author = guide.author
                            {
                                Label(author, systemImage: "person.circle").font(.caption).foregroundColor(.secondary)
                            }
                            if let time = guide.time
                            {
                                Label(time, systemImage: "calendar").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(20)

                    Divider()

                    // HTML 正文
                    if let ctx = guide.context, !ctx.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    {
                        DynamicHTMLView(htmlString: ctx, height: $webHeight)
                            .frame(height: webHeight)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                    else
                    {
                        Text("暂无详细内容").foregroundColor(.secondary).padding(20)
                    }
                    Spacer(minLength: 50)
                }
            }
        }
        .navigationTitle(viewModel.guide?.name ?? "攻略详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.fetchDetail(id: guideId) }
    }
}
