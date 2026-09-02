//
//  shishanyouniTests.swift
//  shishanyouniTests
//
//  Created by douer_lucky on 2026/2/4.
//

import Testing
import Foundation
@testable import shishanyouni

struct shishanyouniTests {

    @Test func parsesSchoolCalendarPageEntries() throws {
        let html = """
        var rc=[];
        rc.push({
            type: 'type0',
            bgdate: '2026-08-31',
            eddate: '2026-09-06',
            title:'开学周',
            bzinfo:'开学周不排课'
        });
        rc.push({
            type: 'type4',
            bgdate: '2026-10-23',
            eddate: '2026-10-24',
            title:'运动会禁排',
            bzinfo:'运动会禁排（禁排已控制）'
        });
        """

        let events = SchoolCalendarFetcher.parseEmbeddedCalendarEvents(from: html)
        let openingWeek = try #require(events.first)
        let sportsMeet = try #require(events.last)

        #expect(events.count == 2)
        #expect(openingWeek.title == "开学周")
        #expect(openingWeek.description == "开学周不排课")
        #expect(openingWeek.type == .trimesterStart)
        #expect(openingWeek.endDate != nil)
        #expect(sportsMeet.title == "运动会禁排")
        #expect(sportsMeet.type == .activity)
    }

    @Test func firstLoginUsesRequestedHomepageDefaultsWithoutOverwritingCustomOrder() throws {
        let suiteName = "HomeLayerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let homeLayer = HomeLayer(defaults: defaults)
        #expect(homeLayer.preferredKeys == [.classroom, .physicalCalculator, .bus, .strategy, .club])

        homeLayer.applyFirstLoginDefaultsIfNeeded(for: "2023307210124")
        #expect(homeLayer.preferredKeys == [.grades, .exams, .classroom, .nanhuRun, .bus, .strategy, .club])

        // 已保存的排序属于用户选择；之后再次登录不能恢复成默认七项。
        homeLayer.remove(.bus)
        let restoredLayer = HomeLayer(defaults: defaults)
        restoredLayer.applyFirstLoginDefaultsIfNeeded(for: "2023307210124")
        #expect(restoredLayer.preferredKeys == [.grades, .exams, .classroom, .nanhuRun, .strategy, .club])
    }

}
