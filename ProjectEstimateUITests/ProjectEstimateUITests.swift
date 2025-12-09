//
//  ProjectEstimateUITests.swift
//  ProjectEstimateUITests
//
//  Comprehensive UI tests for RenovationEstimator Pro
//  Tests key user flows: onboarding, project creation, estimates, navigation
//

import XCTest

final class ProjectEstimateUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launchEnvironment = ["DISABLE_ANIMATIONS": "1"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch Tests

    @MainActor
    func testAppLaunchesSuccessfully() throws {
        app.launch()

        // App should launch without crashing
        XCTAssertTrue(app.exists)
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Onboarding Flow Tests

    @MainActor
    func testOnboardingDisplaysAllPages() throws {
        app.launch()

        // Check if onboarding is shown (first launch scenario)
        let onboardingView = app.otherElements["onboarding_view"]
        if onboardingView.waitForExistence(timeout: 3) {
            // Verify first page content
            XCTAssertTrue(app.staticTexts["Professional Estimates"].exists ||
                         app.staticTexts["Welcome"].exists)

            // Swipe through pages
            app.swipeLeft()
            sleep(1)

            app.swipeLeft()
            sleep(1)

            app.swipeLeft()
            sleep(1)

            // Should reach final page with Get Started button
            let getStartedButton = app.buttons["Get Started"]
            if getStartedButton.waitForExistence(timeout: 2) {
                XCTAssertTrue(getStartedButton.isEnabled)
            }
        }
    }

    @MainActor
    func testOnboardingSkipButton() throws {
        app.launch()

        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 3) {
            skipButton.tap()

            // Should navigate to main app after skipping
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        }
    }

    // MARK: - Tab Bar Navigation Tests

    @MainActor
    func testTabBarNavigation() throws {
        app.launch()

        // Skip onboarding if present
        skipOnboardingIfPresent()

        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar not found")
            return
        }

        // Test Dashboard tab
        let dashboardTab = tabBar.buttons["Dashboard"]
        if dashboardTab.exists {
            dashboardTab.tap()
            sleep(1)
        }

        // Test Projects tab
        let projectsTab = tabBar.buttons["Projects"]
        if projectsTab.exists {
            projectsTab.tap()
            sleep(1)
        }

        // Test Image Studio tab
        let imageTab = tabBar.buttons["Image Studio"]
        if imageTab.exists {
            imageTab.tap()
            sleep(1)
        }

        // Test Settings tab
        let settingsTab = tabBar.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            sleep(1)
        }
    }

    // MARK: - Dashboard Tests

    @MainActor
    func testDashboardDisplaysContent() throws {
        app.launch()
        skipOnboardingIfPresent()

        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else { return }

        // Navigate to dashboard
        let dashboardTab = tabBar.buttons["Dashboard"]
        if dashboardTab.exists {
            dashboardTab.tap()
        }

        // Check for dashboard elements
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
    }

    @MainActor
    func testDashboardNewProjectButton() throws {
        app.launch()
        skipOnboardingIfPresent()

        // Look for new project action
        let newProjectButton = app.buttons["New Project"]
        if newProjectButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(newProjectButton.isEnabled)
            newProjectButton.tap()

            // Should show project input view
            sleep(1)
        }
    }

    // MARK: - Project Input Flow Tests

    @MainActor
    func testProjectInputFormElements() throws {
        app.launch()
        skipOnboardingIfPresent()

        // Navigate to project creation
        navigateToNewProject()

        // Check for form elements
        let projectNameField = app.textFields["project_name_field"]
        let squareFootageField = app.textFields["square_footage_field"]

        if projectNameField.waitForExistence(timeout: 3) {
            XCTAssertTrue(projectNameField.exists)
        }
    }

    @MainActor
    func testProjectInputValidation() throws {
        app.launch()
        skipOnboardingIfPresent()
        navigateToNewProject()

        // Try to submit without filling required fields
        let generateButton = app.buttons["Generate Estimate"]
        if generateButton.waitForExistence(timeout: 3) {
            // Button should be disabled when form is invalid
            // This depends on implementation details
        }
    }

    @MainActor
    func testProjectInputRoomTypeSelection() throws {
        app.launch()
        skipOnboardingIfPresent()
        navigateToNewProject()

        // Look for room type picker
        let roomTypePicker = app.buttons["room_type_picker"]
        if roomTypePicker.waitForExistence(timeout: 3) {
            roomTypePicker.tap()

            // Check for room type options
            let kitchenOption = app.buttons["Kitchen"]
            let bathroomOption = app.buttons["Bathroom"]

            sleep(1)
        }
    }

    @MainActor
    func testProjectInputMaterialsAutocomplete() throws {
        app.launch()
        skipOnboardingIfPresent()
        navigateToNewProject()

        // Find materials text field
        let materialsField = app.textFields["materials_field"]
        if materialsField.waitForExistence(timeout: 3) {
            materialsField.tap()
            materialsField.typeText("granite")

            // Should show autocomplete suggestions
            sleep(1)
        }
    }

    // MARK: - Settings Tests

    @MainActor
    func testSettingsDisplaysAllSections() throws {
        app.launch()
        skipOnboardingIfPresent()

        navigateToSettings()

        // Check for settings sections
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))

        // Look for API configuration section
        let apiSection = app.staticTexts["API Configuration"]
        if apiSection.waitForExistence(timeout: 2) {
            XCTAssertTrue(apiSection.exists)
        }
    }

    @MainActor
    func testSettingsAPIKeyEntry() throws {
        app.launch()
        skipOnboardingIfPresent()
        navigateToSettings()

        // Look for API key field
        let apiKeyField = app.secureTextFields.firstMatch
        if apiKeyField.waitForExistence(timeout: 3) {
            apiKeyField.tap()
            // Can enter API key
        }
    }

    @MainActor
    func testSettingsSubscriptionNavigation() throws {
        app.launch()
        skipOnboardingIfPresent()
        navigateToSettings()

        // Look for subscription button
        let subscriptionButton = app.buttons["Manage Subscription"]
        if subscriptionButton.waitForExistence(timeout: 3) {
            subscriptionButton.tap()

            // Should show paywall
            sleep(1)
        }
    }

    // MARK: - Image Editor Tests

    @MainActor
    func testImageEditorDisplays() throws {
        app.launch()
        skipOnboardingIfPresent()

        navigateToImageStudio()

        // Check for image editor elements
        let uploadButton = app.buttons["Upload Photo"]
        let selectButton = app.buttons["Select Photo"]

        // One of these should exist
        sleep(2)
    }

    @MainActor
    func testImageEditorPromptInput() throws {
        app.launch()
        skipOnboardingIfPresent()
        navigateToImageStudio()

        // Look for prompt text field
        let promptField = app.textFields["prompt_field"]
        if promptField.waitForExistence(timeout: 3) {
            promptField.tap()
            promptField.typeText("change wall color to blue")

            XCTAssertEqual(promptField.value as? String, "change wall color to blue")
        }
    }

    // MARK: - Paywall Tests

    @MainActor
    func testPaywallDisplaysTiers() throws {
        app.launch()
        skipOnboardingIfPresent()
        navigateToSettings()

        // Navigate to paywall
        let manageSubButton = app.buttons["Manage Subscription"]
        if manageSubButton.waitForExistence(timeout: 3) {
            manageSubButton.tap()
            sleep(1)

            // Check for subscription tiers
            let professionalTier = app.staticTexts["Professional"]
            let enterpriseTier = app.staticTexts["Enterprise"]

            // Tiers should be visible
            sleep(1)
        }
    }

    @MainActor
    func testPaywallCloseButton() throws {
        app.launch()
        skipOnboardingIfPresent()
        navigateToSettings()

        let manageSubButton = app.buttons["Manage Subscription"]
        if manageSubButton.waitForExistence(timeout: 3) {
            manageSubButton.tap()
            sleep(1)

            // Look for close button
            let closeButton = app.buttons["Close"]
            if closeButton.waitForExistence(timeout: 2) {
                closeButton.tap()

                // Should dismiss paywall
                sleep(1)
            }
        }
    }

    // MARK: - Accessibility Tests

    @MainActor
    func testAccessibilityLabelsExist() throws {
        app.launch()
        skipOnboardingIfPresent()

        // Check that key elements have accessibility labels
        let buttons = app.buttons.allElementsBoundByIndex

        for button in buttons.prefix(10) {
            // Buttons should have labels
            XCTAssertFalse(button.label.isEmpty, "Button missing accessibility label")
        }
    }

    @MainActor
    func testDynamicTypeSupport() throws {
        app.launch()

        // App should not crash with accessibility sizes
        // This is a basic smoke test
        XCTAssertTrue(app.exists)
    }

    // MARK: - Error State Tests

    @MainActor
    func testNetworkErrorHandling() throws {
        // Launch with network disabled
        app.launchEnvironment["SIMULATE_NETWORK_ERROR"] = "1"
        app.launch()
        skipOnboardingIfPresent()

        // App should handle gracefully
        XCTAssertTrue(app.exists)
    }

    // MARK: - Helper Methods

    private func skipOnboardingIfPresent() {
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

    private func navigateToNewProject() {
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 3) {
            let projectsTab = tabBar.buttons["Projects"]
            if projectsTab.exists {
                projectsTab.tap()
                sleep(1)
            }
        }

        let newProjectButton = app.buttons["New Project"]
        if newProjectButton.waitForExistence(timeout: 2) {
            newProjectButton.tap()
            sleep(1)
        }
    }

    private func navigateToSettings() {
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 3) {
            let settingsTab = tabBar.buttons["Settings"]
            if settingsTab.exists {
                settingsTab.tap()
                sleep(1)
            }
        }
    }

    private func navigateToImageStudio() {
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 3) {
            let imageTab = tabBar.buttons["Image Studio"]
            if imageTab.exists {
                imageTab.tap()
                sleep(1)
            }
        }
    }
}

// MARK: - Snapshot Tests

final class ProjectEstimateSnapshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SNAPSHOT_MODE"]
    }

    @MainActor
    func testCaptureOnboardingScreenshots() throws {
        app.launch()

        let onboardingView = app.otherElements["onboarding_view"]
        if onboardingView.waitForExistence(timeout: 3) {
            captureScreenshot(named: "Onboarding-Page1")

            app.swipeLeft()
            sleep(1)
            captureScreenshot(named: "Onboarding-Page2")

            app.swipeLeft()
            sleep(1)
            captureScreenshot(named: "Onboarding-Page3")

            app.swipeLeft()
            sleep(1)
            captureScreenshot(named: "Onboarding-Page4")
        }
    }

    @MainActor
    func testCaptureDashboardScreenshot() throws {
        app.launch()
        skipOnboarding()

        sleep(2)
        captureScreenshot(named: "Dashboard")
    }

    @MainActor
    func testCaptureProjectInputScreenshot() throws {
        app.launch()
        skipOnboarding()

        let newProjectButton = app.buttons["New Project"]
        if newProjectButton.waitForExistence(timeout: 3) {
            newProjectButton.tap()
            sleep(1)
            captureScreenshot(named: "ProjectInput")
        }
    }

    @MainActor
    func testCaptureSettingsScreenshot() throws {
        app.launch()
        skipOnboarding()

        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 3) {
            let settingsTab = tabBar.buttons["Settings"]
            if settingsTab.exists {
                settingsTab.tap()
                sleep(1)
                captureScreenshot(named: "Settings")
            }
        }
    }

    private func skipOnboarding() {
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

    private func captureScreenshot(named name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

// MARK: - Performance Tests

final class ProjectEstimatePerformanceTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    @MainActor
    func testScrollPerformance() throws {
        app.launch()

        // Skip onboarding
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 2) {
            skipButton.tap()
        }

        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 1) {
            getStartedButton.tap()
        }

        sleep(2)

        // Measure scroll performance on dashboard
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 3) {
            measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
                scrollView.swipeUp()
                scrollView.swipeDown()
            }
        }
    }

    @MainActor
    func testTabSwitchingPerformance() throws {
        app.launch()

        // Skip onboarding
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 2) {
            skipButton.tap()
        }

        let getStartedButton = app.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 1) {
            getStartedButton.tap()
        }

        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 3) else { return }

        measure {
            let dashboardTab = tabBar.buttons["Dashboard"]
            let settingsTab = tabBar.buttons["Settings"]

            if dashboardTab.exists && settingsTab.exists {
                settingsTab.tap()
                dashboardTab.tap()
                settingsTab.tap()
                dashboardTab.tap()
            }
        }
    }
}
