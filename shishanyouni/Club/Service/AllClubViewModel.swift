import SwiftUI

// MARK: - ViewModel

@MainActor
class AllClubViewModel: ObservableObject
{
    @Published var groupedClubs: [(letter: String, clubs: [Club])] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let letters: [String] = (65 ... 90).map { String(UnicodeScalar($0)!) }

    func fetchClubs() async
    {
        do
        {
            let clubs = try await ClubAPI.fetchClubs()
            groupedClubs = zip(letters, clubs).compactMap
            { letter, clubs in
                clubs.isEmpty ? nil : (letter: letter, clubs: clubs)
            }
        }
        catch
        {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    func filtered(by query: String) -> [(letter: String, clubs: [Club])]
    {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return groupedClubs }
        return groupedClubs.compactMap
        { item in
            let matched = item.clubs.filter { $0.name.localizedCaseInsensitiveContains(query) }
            return matched.isEmpty ? nil : (letter: item.letter, clubs: matched)
        }
    }
}
