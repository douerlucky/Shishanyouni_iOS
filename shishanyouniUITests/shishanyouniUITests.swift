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
    func testFirstLaunchDisclaimerRequiresConsent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-app-disclaimer"]
        app.launch()

        let disclaimer = app.alerts["使用声明"]
        XCTAssertTrue(disclaimer.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["我的"].exists)

        disclaimer.buttons["不同意"].tap()
        let blockedMessage = app.staticTexts["disclaimerWelcomeMessage"]
        XCTAssertTrue(blockedMessage.waitForExistence(timeout: 3))
        XCTAssertTrue(blockedMessage.label.contains("无法继续使用"))
        XCTAssertFalse(app.tabBars.buttons["我的"].exists)

        app.buttons["重新查看声明"].tap()
        XCTAssertTrue(disclaimer.waitForExistence(timeout: 3))
        disclaimer.buttons["同意，继续"].tap()
        XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout: 5))

        // 同意状态需要落盘；再次启动不应重复打断用户。
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["使用声明"].exists)
    }

    @MainActor
    func testSchoolDataQueryDoesNotShowInlineDisclaimer() throws {
        let app = XCUIApplication()
        app.launch()

        let agreeButton = app.alerts["使用声明"].buttons["同意，继续"]
        if agreeButton.waitForExistence(timeout: 3) { agreeButton.tap() }
        for title in ["允许", "Allow", "不允许", "Don’t Allow"] {
            let button = app.alerts.buttons[title]
            if button.waitForExistence(timeout: 1) { button.tap(); break }
        }
        let startButton = app.buttons["开始使用"]
        if startButton.waitForExistence(timeout: 3) { startButton.tap() }

        let homeTab = app.tabBars.buttons["首页"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        homeTab.tap()

        let classroomLink = app.staticTexts["空教室查询"].firstMatch
        for _ in 0 ..< 5 {
            if classroomLink.exists && classroomLink.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(classroomLink.isHittable)
        // 首页常用功能是 UIKit CollectionView 单元格，点击整个单元格而非内部标签。
        app.collectionViews.cells.containing(.staticText, identifier: "空教室查询").firstMatch.tap()

        // 查询页面不再插入影响观感的固定声明条；需要账号授权的功能会使用独立 Sheet。
        XCTAssertFalse(app.staticTexts["schoolDataDisclaimer"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testCurriculumScaleSliderRemainsResponsive() throws {
        let app = XCUIApplication()
        app.launch()

        // 首次启动先确认使用声明，再处理通知授权和更新说明。
        let agreeButton = app.alerts["使用声明"].buttons["同意，继续"]
        if agreeButton.waitForExistence(timeout: 3) { agreeButton.tap() }
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
