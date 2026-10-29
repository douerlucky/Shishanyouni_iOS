import Foundation

/// 狮山有你课表接口；课程合并、配色和日期转换由 Importer 处理。
enum ShishanyouniCurriculumAPI
{
    static func fetchTimetable(
        username: String,
        encryptedPassword: String,
        year: String,
        term: String,
        mfa: ShishanyouniV3MFAProvider? = nil
    ) async throws -> TimetableData
    {
        guard !year.isEmpty, ["1", "2"].contains(term) else { throw ShishanyouniV3Error.invalidParameters }
        let data = try await ShishanyouniV3Session.shared.request(
            .timetable, username: username, encryptedPassword: encryptedPassword,
            parameters: ["year": year, "term": term], mfa: mfa
        )
        return try JSONDecoder().decode(ShishanyouniV3Data<TimetableData>.self, from: data).data
    }
}
