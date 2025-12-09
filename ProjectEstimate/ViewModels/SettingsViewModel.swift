//
//  SettingsViewModel.swift
//  ProjectEstimate
//
//  ViewModel for app settings and API configuration
//  Manages user preferences, API keys, and app configuration
//

import Foundation
import SwiftUI
import OSLog

// MARK: - Settings ViewModel

@MainActor
@Observable
final class SettingsViewModel {

    // MARK: - API Configuration

    var geminiAPIKey: String = ""
    var imagenAPIKey: String = ""
    var isValidatingAPIKey = false
    var apiKeyValidationStatus: APIKeyValidationStatus = .unknown
    var showAPIKeyInput = false

    // MARK: - Appearance Settings

    var colorSchemePreference: ColorSchemePreference = .system
    var accentColorChoice: AccentColorChoice = .blue
    var useDynamicType = true
    var reduceMotion = false

    // MARK: - Notification Settings

    var enablePushNotifications = true
    var enableEmailNotifications = false
    var notifyOnEstimateComplete = true

    // MARK: - Export Settings

    var defaultPDFFormat: PDFFormat = .letter
    var includeImagesInPDF = true
    var companyName: String = ""
    var companyLogo: Data?

    // MARK: - Privacy Settings

    var enableAnalytics = true
    var enableCrashReporting = true

    // MARK: - Account Info

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Error State

    var error: Error?
    var showError = false
    var successMessage: String?
    var showSuccess = false

    // MARK: - Dependencies

    private let keyManager: APIKeyManager
    private let logger = Logger(subsystem: "com.projectestimate", category: "Settings")

    // MARK: - Initialization

    init(keyManager: APIKeyManager = APIKeyManager()) {
        self.keyManager = keyManager
        loadSettings()
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        let defaults = UserDefaults.standard

        // Appearance
        if let rawValue = defaults.string(forKey: "colorSchemePreference"),
           let preference = ColorSchemePreference(rawValue: rawValue) {
            colorSchemePreference = preference
        }

        if let rawValue = defaults.string(forKey: "accentColorChoice"),
           let choice = AccentColorChoice(rawValue: rawValue) {
            accentColorChoice = choice
        }

        useDynamicType = defaults.bool(forKey: "useDynamicType")
        reduceMotion = defaults.bool(forKey: "reduceMotion")

        // Notifications
        enablePushNotifications = defaults.bool(forKey: "enablePushNotifications")
        enableEmailNotifications = defaults.bool(forKey: "enableEmailNotifications")
        notifyOnEstimateComplete = defaults.bool(forKey: "notifyOnEstimateComplete")

        // Export
        if let rawValue = defaults.string(forKey: "defaultPDFFormat"),
           let format = PDFFormat(rawValue: rawValue) {
            defaultPDFFormat = format
        }

        includeImagesInPDF = defaults.bool(forKey: "includeImagesInPDF")
        companyName = defaults.string(forKey: "companyName") ?? ""
        companyLogo = defaults.data(forKey: "companyLogo")

        // Privacy
        enableAnalytics = defaults.bool(forKey: "enableAnalytics")
        enableCrashReporting = defaults.bool(forKey: "enableCrashReporting")

        // Check API key status
        checkAPIKeyStatus()
    }

    func saveSettings() {
        let defaults = UserDefaults.standard

        defaults.set(colorSchemePreference.rawValue, forKey: "colorSchemePreference")
        defaults.set(accentColorChoice.rawValue, forKey: "accentColorChoice")
        defaults.set(useDynamicType, forKey: "useDynamicType")
        defaults.set(reduceMotion, forKey: "reduceMotion")

        defaults.set(enablePushNotifications, forKey: "enablePushNotifications")
        defaults.set(enableEmailNotifications, forKey: "enableEmailNotifications")
        defaults.set(notifyOnEstimateComplete, forKey: "notifyOnEstimateComplete")

        defaults.set(defaultPDFFormat.rawValue, forKey: "defaultPDFFormat")
        defaults.set(includeImagesInPDF, forKey: "includeImagesInPDF")
        defaults.set(companyName, forKey: "companyName")
        defaults.set(companyLogo, forKey: "companyLogo")

        defaults.set(enableAnalytics, forKey: "enableAnalytics")
        defaults.set(enableCrashReporting, forKey: "enableCrashReporting")

        logger.info("Settings saved")
    }

    // MARK: - API Key Management

    func checkAPIKeyStatus() {
        if keyManager.hasAPIKeysConfigured {
            apiKeyValidationStatus = .valid
        } else {
            apiKeyValidationStatus = .notConfigured
        }
    }

    func saveGeminiAPIKey() async {
        guard !geminiAPIKey.isEmpty else {
            error = NSError(domain: "Settings", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Please enter an API key"
            ])
            showError = true
            return
        }

        isValidatingAPIKey = true
        apiKeyValidationStatus = .validating

        do {
            try await keyManager.setGeminiAPIKey(geminiAPIKey)

            // Validate the key
            let geminiService = GeminiAPIService()
            let isValid = try await geminiService.validateAPIKey()

            if isValid {
                apiKeyValidationStatus = .valid
                successMessage = "API key saved and validated successfully"
                showSuccess = true
                geminiAPIKey = "" // Clear the input
                AppState.shared.setAPIKeyConfigured(true)
                logger.info("Gemini API key saved and validated")
            } else {
                apiKeyValidationStatus = .invalid
                error = NSError(domain: "Settings", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "API key validation failed"
                ])
                showError = true
            }
        } catch {
            apiKeyValidationStatus = .invalid
            self.error = error
            showError = true
            logger.error("Failed to save API key: \(error.localizedDescription)")
        }

        isValidatingAPIKey = false
    }

    func removeAPIKey() async {
        do {
            try KeychainService.shared.clearAllCredentials()
            apiKeyValidationStatus = .notConfigured
            AppState.shared.setAPIKeyConfigured(false)
            successMessage = "API key removed"
            showSuccess = true
            logger.info("API key removed")
        } catch {
            self.error = error
            showError = true
        }
    }

    // MARK: - Data Management

    func exportAllData() async -> URL? {
        logger.info("Exporting all data...")

        // Create export data structure
        let exportData: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "appVersion": appVersion,
            "buildNumber": buildNumber,
            "settings": [
                "colorSchemePreference": colorSchemePreference.rawValue,
                "accentColorChoice": accentColorChoice.rawValue,
                "useDynamicType": useDynamicType,
                "reduceMotion": reduceMotion,
                "defaultPDFFormat": defaultPDFFormat.rawValue,
                "includeImagesInPDF": includeImagesInPDF,
                "companyName": companyName,
                "enableAnalytics": enableAnalytics,
                "enableCrashReporting": enableCrashReporting
            ]
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("projectestimate_export_\(Date().timeIntervalSince1970).json")

            try jsonData.write(to: tempURL)
            logger.info("Data exported to: \(tempURL.path)")

            successMessage = "Data exported successfully"
            showSuccess = true

            return tempURL
        } catch {
            self.error = error
            showError = true
            logger.error("Export failed: \(error.localizedDescription)")
            return nil
        }
    }

    func clearAllData() async {
        logger.warning("Clearing all data...")

        do {
            // Clear keychain credentials
            try KeychainService.shared.clearAllCredentials()

            // Reset all settings to defaults
            resetToDefaults()

            // Clear API key status
            apiKeyValidationStatus = .notConfigured
            AppState.shared.setAPIKeyConfigured(false)

            // Clear UserDefaults
            let domain = Bundle.main.bundleIdentifier ?? "com.projectestimate"
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()

            successMessage = "All data cleared successfully"
            showSuccess = true
            logger.info("All data cleared")
        } catch {
            self.error = error
            showError = true
            logger.error("Clear data failed: \(error.localizedDescription)")
        }
    }

    func resetToDefaults() {
        colorSchemePreference = .system
        accentColorChoice = .blue
        useDynamicType = true
        reduceMotion = false
        enablePushNotifications = true
        enableEmailNotifications = false
        notifyOnEstimateComplete = true
        defaultPDFFormat = .letter
        includeImagesInPDF = true
        companyName = ""
        companyLogo = nil
        enableAnalytics = true
        enableCrashReporting = true

        saveSettings()

        successMessage = "Settings reset to defaults"
        showSuccess = true
    }
}

// MARK: - Supporting Enums

enum APIKeyValidationStatus: String {
    case unknown = "Unknown"
    case notConfigured = "Not Configured"
    case validating = "Validating..."
    case valid = "Valid"
    case invalid = "Invalid"

    var color: Color {
        switch self {
        case .unknown: return .gray
        case .notConfigured: return .orange
        case .validating: return .blue
        case .valid: return .green
        case .invalid: return .red
        }
    }

    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .notConfigured: return "exclamationmark.triangle"
        case .validating: return "arrow.triangle.2.circlepath"
        case .valid: return "checkmark.circle.fill"
        case .invalid: return "xmark.circle.fill"
        }
    }
}

enum ColorSchemePreference: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AccentColorChoice: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case purple = "Purple"
    case red = "Red"
    case teal = "Teal"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .red: return .red
        case .teal: return .teal
        }
    }
}

enum PDFFormat: String, CaseIterable, Identifiable {
    case letter = "Letter (US)"
    case a4 = "A4 (International)"

    var id: String { rawValue }

    var configuration: PDFConfiguration {
        switch self {
        case .letter: return .standard
        case .a4: return .a4
        }
    }
}

// MARK: - Preview Helper

extension SettingsViewModel {
    static var preview: SettingsViewModel {
        SettingsViewModel()
    }
}
