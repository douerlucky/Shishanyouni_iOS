//
//  shishanyouniUITests.swift
//  shishanyouniUITests
//
//  Created by douer_lucky on 2026/2/4.
//

import XCTest

final class shishanyouniUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testCurriculumScaleSliderRemainsResponsive() throws {
        let app = XCUIApplication()
        app.launch()

        // 首次启动可能出现通知授权和更新说明，按正常使用路径进入设置。
        for title in ["允许", "Allow", "不允许", "Don’t Allow"] {
            let button = app.alerts.buttons[title]
            if button.waitForExistence(timeout: 1) { button.tap(); break }
        }
        let startButton = app.buttons["开始使用"]
        if startButton.waitForExistence(timeout: 3) { startButton.tap() }

        let profileTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()

        let settingsLink = app.staticTexts["调整课表显示比例"].firstMatch
        for _ in 0 ..< 4 {
            if settingsLink.exists && settingsLink.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(settingsLink.isHittable)
        settingsLink.tap()

        let slider = app.sliders["课表显示比例"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        let sliderPosition = slider.frame.midY

        // 连续往返拖动，确认值能更新、手势不会被预览高度变化卡住。
        for (position, expectedPercent) in [(0.2, 80), (0.8, 135), (0.35, 95), (0.65, 120)] {
            slider.adjust(toNormalizedSliderPosition: position)
            let label = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "显示比例：")).firstMatch.label
            let percent = Int(label.filter(\.isNumber)) ?? 0
            XCTAssertLessThanOrEqual(abs(percent - expectedPercent), 5)
            XCTAssertEqual(slider.frame.midY, sliderPosition, accuracy: 2)
        }

        app.buttons["恢复默认比例"].tap()
        XCTAssertTrue(app.staticTexts["显示比例：100%"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
