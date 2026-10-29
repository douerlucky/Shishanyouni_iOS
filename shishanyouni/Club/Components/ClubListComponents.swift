import SwiftUI

// MARK: - List + Index Bar

struct ClubIndexList: View
{
    let groups: [(letter: String, clubs: [Club])]
    let searchText: String

    var presentLetters: [String] { groups.map(\.letter) }

    var body: some View
    {
        ScrollViewReader
        { proxy in
            ZStack(alignment: .trailing)
            {
                List
                {
                    if groups.isEmpty
                    {
                        ContentUnavailableRow(query: searchText)
                    }
                    else
                    {
                        ForEach(groups, id: \.letter)
                        { item in
                            Section
                            {
                                ForEach(item.clubs)
                                { club in
                                    NavigationLink(destination: ClubDetailView(clubId: club.id))
                                    {
                                        ClubRow(club: club)
                                    }
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                }
                            } header: {
                                Text(item.letter)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .id(item.letter)
                        }
                    }
                }
                .listStyle(.plain)

                if searchText.isEmpty
                {
                    IndexSidebar(letters: presentLetters, proxy: proxy)
                        .padding(.trailing, 2)
                }
            }
        }
    }
}

// MARK: - Sidebar Index

struct IndexSidebar: View
{
    let letters: [String]
    let proxy: ScrollViewProxy
    @GestureState private var dragLetter: String? = nil

    var body: some View
    {
        VStack(spacing: 0)
        {
            ForEach(letters, id: \.self)
            { letter in
                Text(letter)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(dragLetter == letter ? .white : .accentColor)
                    .frame(width: 22, height: 18)
                    .background(
                        Group
                        {
                            if dragLetter == letter
                            {
                                Circle().fill(Color.accentColor)
                            }
                            else
                            {
                                Color.clear
                            }
                        }
                    )
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .updating($dragLetter)
                { value, state, _ in
                    let itemHeight: CGFloat = 18
                    let index = max(0, min(letters.count - 1, Int(value.location.y / itemHeight)))
                    let letter = letters[index]
                    state = letter
                    DispatchQueue.main.async
                    {
                        withAnimation(.none) { proxy.scrollTo(letter, anchor: .top) }
                    }
                }
        )
    }
}

// MARK: - Club Row

struct ClubRow: View
{
    let club: Club

    var body: some View
    {
        HStack(spacing: 12)
        {
            AsyncImage(url: URL(string: club.avatar))
            { phase in
                switch phase
                {
                case let .success(image):
                    image.resizable().scaledToFill()
                case .failure:
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray5))
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray6))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 2)
            {
                Text(club.name)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let intro = club.introduction, !intro.isEmpty
                {
                    Text(intro)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Empty State

struct ContentUnavailableRow: View
{
    let query: String
    var body: some View
    {
        VStack(spacing: 12)
        {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("未找到\(query)相关社团")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowSeparator(.hidden)
    }
}

// MARK: - Preview

#Preview
{
    AllClub()
}
