import Foundation
import SwiftUI

/// 统一处理教务请求头、表单编码和会话失效检查。
/// 写请求调用时会传 `retryCount: 0`，确保网络超时也不会把选/退课重复提交。
enum CourseSelectionHTTP
{
    static func send(
        urlString: String,
        method: String,
        cookie: String,
        parameters: [(String, String)] = [],
        accept: String = "application/json, text/javascript, */*; q=0.01",
        expectsJSON: Bool,
        retryCount: Int
    ) async throws -> (Data, HTTPURLResponse)
    {
        guard let url = URL(string: urlString) else
        {
            throw CourseSelectionServiceError.invalidURL
        }
        return try await send(
            url: url,
            method: method,
            cookie: cookie,
            parameters: parameters,
            accept: accept,
            expectsJSON: expectsJSON,
            retryCount: retryCount
        )
    }

    static func send(
        url: URL,
        method: String,
        cookie: String,
        parameters: [(String, String)] = [],
        accept: String = "application/json, text/javascript, */*; q=0.01",
        expectsJSON: Bool,
        retryCount: Int
    ) async throws -> (Data, HTTPURLResponse)
    {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue(SchoolDirectAPI.academicOrigin, forHTTPHeaderField: "Origin")
        request.setValue(SchoolDirectAPI.courseSelectionIndexURL, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        if method.uppercased() == "POST"
        {
            request.httpBody = formEncodedData(parameters)
        }

        ChooseCourseDebug.request(
            url: url,
            method: method,
            parameters: parameters,
            retryCount: retryCount,
            hasCookie: !cookie.isEmpty
        )
        do
        {
            let (data, response) = try await NetworkService.perform(request: request, retries: retryCount)
            guard let httpResponse = response as? HTTPURLResponse else
            {
                throw CourseSelectionServiceError.invalidResponse("教务服务")
            }
            ChooseCourseDebug.response(url: url, response: httpResponse, data: data)
            try validate(httpResponse: httpResponse, data: data, expectsJSON: expectsJSON)
            return (data, httpResponse)
        }
        catch
        {
            ChooseCourseDebug.requestFailed(url: url, error: error)
            throw error
        }
    }

    static func urlByAppendingQueryItems(
        _ urlString: String,
        parameters: [(String, String)]
    ) throws -> URL
    {
        guard var components = URLComponents(string: urlString) else
        {
            throw CourseSelectionServiceError.invalidURL
        }
        var queryItems = components.queryItems ?? []
        queryItems.append(contentsOf: parameters.map { URLQueryItem(name: $0.0, value: $0.1) })
        components.queryItems = queryItems
        guard let url = components.url else
        {
            throw CourseSelectionServiceError.invalidURL
        }
        return url
    }

    static func formEncodedData(_ parameters: [(String, String)]) -> Data?
    {
        parameters
            .map { "\(formEncode($0.0))=\(formEncode($0.1))" }
            .joined(separator: "&")
            .data(using: .utf8)
    }

    static func formEncode(_ value: String) -> String
    {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    static func validate(httpResponse: HTTPURLResponse, data: Data, expectsJSON: Bool) throws
    {
        if httpResponse.statusCode == 910
        {
            throw CourseSelectionServiceError.invalidResponse("选课页上下文")
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else
        {
            throw CourseSelectionServiceError.serverError(operation: "教务服务", statusCode: httpResponse.statusCode)
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""
        if looksLikeLoginPage(responseText)
        {
            throw CourseSelectionServiceError.sessionExpired
        }
        if expectsJSON && responseText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<")
        {
            throw CourseSelectionServiceError.invalidResponse("教务服务")
        }
    }

    static func looksLikeLoginPage(_ text: String) -> Bool
    {
        text.contains("统一身份认证")
            || text.contains("用户登录")
            || text.contains(SchoolDirectAPI.casLoginResponseMarker)
            || text.contains("name=\"execution\"")
    }
}
