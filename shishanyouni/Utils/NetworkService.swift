//
//  NetworkService.swift
//  shishanyouni
//

import Foundation

enum NetworkService
{
    static let defaultTimeout: TimeInterval = 30
    static let maxRetries = 3
    static let baseRetryDelay: TimeInterval = 1.0

    private static func isRetryable(_ error: Error) -> Bool
    {
        let code = (error as NSError).code
        switch code
        {
        case NSURLErrorTimedOut,
             NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorDNSLookupFailed,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorSecureConnectionFailed,
             NSURLErrorCannotLoadFromNetwork,
             NSURLErrorDataNotAllowed,
             NSURLErrorInternationalRoamingOff,
             NSURLErrorCallIsActive:
            return true
        default:
            return false
        }
    }

    static func perform(
        with session: URLSession = .shared,
        request: URLRequest,
        retries: Int = maxRetries,
        timeout: TimeInterval = defaultTimeout
    ) async throws -> (Data, URLResponse)
    {
        var mutableRequest = request
        mutableRequest.timeoutInterval = timeout

        var lastError: Error?

        for attempt in 0 ... retries
        {
            do
            {
                return try await session.data(for: mutableRequest)
            }
            catch
            {
                lastError = error
                if attempt < retries, isRetryable(error)
                {
                    let delay = baseRetryDelay * pow(2.0, Double(attempt))
                    print("🔄 网络请求失败，\(String(format: "%.1f", delay))秒后第\(attempt + 1)次重试…")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw error
            }
        }

        throw lastError ?? NSError(domain: "NetworkService", code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: "未知网络错误"])
    }
}
