import Foundation

/// 社团接口只负责请求和解码，字母分组与搜索由 Service 处理。
enum ClubAPI
{
    static func fetchClubs() async throws -> [[Club]]
    {
        guard let url = URL(string: ShishanyouniAPI.clubListURL) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ClubListResponse.self, from: data).data
    }

    static func fetchDetail(id: Int) async throws -> ClubDetail
    {
        guard let url = URL(string: "\(ShishanyouniAPI.clubDetailURL)?id=\(id)") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ClubDetailResponse.self, from: data).data
    }
}
