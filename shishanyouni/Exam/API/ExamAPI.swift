import Foundation

class ExamAPI
{
    static let shared = ExamAPI()
    private let backendSession: ShishanyouniV3Session

    init(backendSession: ShishanyouniV3Session = .shared) { self.backendSession = backendSession }

    func fetchExams(cookie: String, xnm: String, xqm: String) async throws -> [Exam]
    {
        let urlString = SchoolDirectAPI.examURL
        guard let url = URL(string: urlString) else { throw NSError(domain: "URLError", code: 400) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue(SchoolDirectAPI.academicTimetableReferer, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        let params = [
            "xnm": xnm,
            "xqm": xqm,
            "queryModel.showCount": "100",
            "queryModel.currentPage": "1",
        ]

        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, _) = try await NetworkService.perform(request: request)
        let response = try JSONDecoder().decode(ExamResponse.self, from: data)
        return response.items
    }

    func fetchExamsFromShishanyouni(
        username: String, encryptedPassword: String, xnm: String, xqm: String,
        mfa: ShishanyouniV3MFAProvider? = nil
    ) async throws -> [Exam] {
        guard !xnm.isEmpty, ["1", "2"].contains(xqm) else { throw ShishanyouniV3Error.invalidParameters }
        let data = try await backendSession.request(
            .exam, username: username, encryptedPassword: encryptedPassword,
            parameters: ["xnm": xnm, "xqm": xqm], mfa: mfa
        )
        let decoded = try JSONDecoder().decode(LionExamResponse.self, from: data)
        return (decoded.data ?? [])
            .map { Exam(from: $0) }
            .sorted { $0.kssj < $1.kssj }
    }
}
