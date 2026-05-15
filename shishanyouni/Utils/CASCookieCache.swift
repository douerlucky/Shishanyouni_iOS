//
//  CASCookieCache.swift
//  shishanyouni
//
//  Created by Codex on 2026/5/16.
//

import Foundation

enum CASCookieCache
{
    private struct Entry: Codable
    {
        let cookies: [String: String]
        let savedAt: Date
        let ttl: TimeInterval

        var isValid: Bool
        {
            Date().timeIntervalSince(savedAt) < ttl
        }
    }

    static let defaultTTL: TimeInterval = 30 * 60
    private static let prefix = "casCookieCache"

    static func load(namespace: String, username: String) -> [String: String]?
    {
        let cacheKey = key(namespace: namespace, username: username)
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              entry.isValid
        else
        {
            UserDefaults.standard.removeObject(forKey: cacheKey)
            return nil
        }

        return entry.cookies
    }

    static func save(_ cookies: [String: String], namespace: String, username: String, ttl: TimeInterval = defaultTTL)
    {
        guard !cookies.isEmpty else { return }
        let entry = Entry(cookies: cookies, savedAt: Date(), ttl: ttl)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        UserDefaults.standard.set(data, forKey: key(namespace: namespace, username: username))
    }

    static func clear(namespace: String, username: String)
    {
        UserDefaults.standard.removeObject(forKey: key(namespace: namespace, username: username))
    }

    private static func key(namespace: String, username: String) -> String
    {
        "\(prefix).\(namespace).\(username)"
    }
}
