//
//  ProjectEstimateUITestsLaunchTests.swift
//  ProjectEstimateUITests
//
//  Launch tests and screenshot generation for App Store
//

import XCTest

final class ProjectEstimateUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch Tests

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchInDarkMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["DARK_MODE"]
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen - Dark Mode"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - App Store Screenshot Generation

    @MainActor
    func testGenerateAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SCREENSHOT_MODE"]
        app.launch()

        // Skip onboarding
        skipOnboarding(app: app)

        // Screenshot 1: Dashboard
        sleep(2)
        captureScreenshot(app: app, named: "01_Dashboard")

        // Screenshot 2: New Project Form
        let newProjectButton = app.buttons["New Project"]
        if newProjectButton.waitForExistence(timeout: 3) {
            newProjectButton.tap()
            sleep(1)
            captureScreenshot(app: app, named: "02_NewProject")

            // Dismiss if possible
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
                sleep(1)
            }
        }

        // Screenshot 3: Image Studio
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 3) {
            let imageTab = tabBar.buttons["Image Studio"]
            if imageTab.exists {
                imageTab.tap()
                sleep(1)
                captureScreenshot(app: app, named: "03_ImageStudio")
            }
        }

        // Screenshot 4: Settings
        if tabBar.exists {
            let settingsTab = tabBar.buttons["Settings"]
            if settingsTab.exists {
                settingsTab.tap()
                sleep(1)
                captureScreenshot(app: app, named: "04_Settings")
            }
        }
    }

    @MainActor
    func testGenerateOnboardingScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "RESET_ONBOARDING"]
        app.launch()

        let onboardingView = app.otherElements["onboarding_view"]
        if onboardingView.waitForExistence(timeout: 3) {
            captureScreenshot(app: app, named: "Onboarding_01_Welcome")

            app.swipeLeft()
            sleep(1)
            captureScreenshot(app: app, named: "Onboarding_02_AIEstimates")

            app.swipeLeft()
            sleep(1)
            captureScreenshot(app: app, named: "Onboarding_03_Visualization")

            app.swipeLeft()
            sleep(1)
            captureScreenshot(app: app, named: "Onboarding_04_GetStarted")
        }
    }

    // MARK: - Device Specific Screenshots

    @MainActor
    func testIPadDashboardLayout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()

        skipOnboarding(app: app)
        sleep(2)

        // Capture iPad-specific layout
        captureScreenshot(app: app, named: "iPad_Dashboard")
    }

    // MARK: - Localization Screenshots

    @MainActor
    func testLocalizedScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        // Locale would be set via scheme or environment
        app.launch()

        skipOnboarding(app: app)
        sleep(2)

        captureScreenshot(app: app, named: "Localized_Dashboard")
    }

    // MARK: - Helper Methods

    private func skipOnboarding(app: XCUIApplication) {
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 2) {
            skipButton.tap()
            sleep(1)
        }

        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 1) {
            getStartedButton.tap()
            sleep(1)
        }
    }

    private func captureScreenshot(app: XCUIApplication, named name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

// MARK: - Accessibility Launch Tests

final class ProjectEstimateAccessibilityLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchWithLargeText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "LARGE_TEXT"]
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch - Large Text"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchWithReducedMotion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "REDUCE_MOTION"]
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch - Reduced Motion"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchWithHighContrast() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "HIGH_CONTRAST"]
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch - High Contrast"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
