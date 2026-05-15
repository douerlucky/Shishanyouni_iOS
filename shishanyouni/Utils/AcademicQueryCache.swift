//
//  AcademicQueryCache.swift
//  shishanyouni
//
//  Created by Codex on 2026/5/12.
//

import Foundation

enum AcademicQueryCache
{
    private static let prefix = "academicQueryCache"

    static func load<T: Decodable>(_ type: T.Type, namespace: String, username: String, parts: [String]) -> T?
    {
        let key = cacheKey(namespace: namespace, username: username, parts: parts)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, namespace: String, username: String, parts: [String])
    {
        let key = cacheKey(namespace: namespace, username: username, parts: parts)
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func cacheKey(namespace: String, username: String, parts: [String]) -> String
    {
        ([prefix, namespace, sanitized(username)] + parts.map(sanitized)).joined(separator: ".")
    }

    private static func sanitized(_ raw: String) -> String
    {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
    }
}
