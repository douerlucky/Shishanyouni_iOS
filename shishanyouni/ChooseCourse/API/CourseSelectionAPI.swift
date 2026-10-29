import Foundation

/// 选课请求的固定协议；业务校验、课程匹配和结果核验由 Service 负责。
enum CourseSelectionAPI
{
    enum Endpoint: CaseIterable
    {
        case index
        case display
        case catalog
        case parentClasses
        case childDialog
        case childClasses
        case submit
        case dropCheck
        case drop
        case preferenceSync

        var urlString: String
        {
            switch self
            {
            case .index: return SchoolDirectAPI.courseSelectionIndexURL
            case .display: return SchoolDirectAPI.courseSelectionDisplayURL
            case .catalog: return SchoolDirectAPI.courseSelectionCatalogURL
            case .parentClasses: return SchoolDirectAPI.courseSelectionParentClassURL
            case .childDialog: return SchoolDirectAPI.courseSelectionChildDialogURL
            case .childClasses: return SchoolDirectAPI.courseSelectionChildDisplayURL
            case .submit: return SchoolDirectAPI.courseSelectionSubmitURL
            case .dropCheck: return SchoolDirectAPI.courseSelectionDropCheckURL
            case .drop: return SchoolDirectAPI.courseSelectionDropURL
            case .preferenceSync: return SchoolDirectAPI.courseSelectionPreferenceSyncURL
            }
        }

        var method: String { self == .index ? "GET" : "POST" }

        var expectsJSON: Bool
        {
            switch self
            {
            case .index, .display, .childDialog: return false
            default: return true
            }
        }

        var retryCount: Int
        {
            switch self
            {
            // 超时也不能自动重发可能改变用户课表的请求。
            case .submit, .drop, .preferenceSync: return 0
            default: return 1
            }
        }

        var accept: String
        {
            expectsJSON ? "application/json, text/javascript, */*; q=0.01" : "text/html, */*; q=0.01"
        }
    }

    static func request(
        _ endpoint: Endpoint,
        cookie: String,
        parameters: [(String, String)] = []
    ) async throws -> Data
    {
        if endpoint == .childDialog
        {
            // 学校网页把子教学班弹窗参数放在 URL 上，POST body 为空；不能改成普通表单。
            let url = try CourseSelectionHTTP.urlByAppendingQueryItems(endpoint.urlString, parameters: parameters)
            let (data, _) = try await CourseSelectionHTTP.send(
                url: url,
                method: endpoint.method,
                cookie: cookie,
                accept: endpoint.accept,
                expectsJSON: endpoint.expectsJSON,
                retryCount: endpoint.retryCount
            )
            return data
        }

        let (data, _) = try await CourseSelectionHTTP.send(
            urlString: endpoint.urlString,
            method: endpoint.method,
            cookie: cookie,
            parameters: parameters,
            accept: endpoint.accept,
            expectsJSON: endpoint.expectsJSON,
            retryCount: endpoint.retryCount
        )
        return data
    }
}
