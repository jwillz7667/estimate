//
//  AppState.swift
//  ProjectEstimate
//
//  Global application state management with dependency injection container
//  Provides centralized state for authentication, settings, and app configuration
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import OSLog

// MARK: - App State

/// Global application state observable object
@MainActor
@Observable
final class AppState {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Navigation State

    var selectedTab: AppTab = .dashboard
    var showOnboarding: Bool = true
    var isAuthenticated: Bool = false

    // MARK: - User State

    var currentUser: User?

    // MARK: - API Configuration

    var hasValidAPIKey: Bool = false

    // MARK: - UI State

    var colorScheme: ColorScheme?
    var isLoading: Bool = false
    var globalError: AppError?

    // MARK: - Feature Flags

    var isImageGenerationEnabled: Bool = true
    var isPDFExportEnabled: Bool = true
    var isOfflineModeEnabled: Bool = true

    // MARK: - Services (Dependency Injection)

    let keyManager: APIKeyManager
    private let logger = Logger(subsystem: "com.projectestimate", category: "AppState")

    // MARK: - Initialization

    private init() {
        self.keyManager = APIKeyManager()

        // Check if onboarding was completed
        self.showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        // Check API key status
        self.hasValidAPIKey = KeychainService.shared.exists(forKey: KeychainService.Keys.geminiAPIKey)
    }

    // MARK: - Methods

    func completeOnboarding() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        logger.info("Onboarding completed")
    }

    func resetOnboarding() {
        showOnboarding = true
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    func setAPIKeyConfigured(_ configured: Bool) {
        hasValidAPIKey = configured
        logger.info("API key configured: \(configured)")
    }

    func logout() {
        currentUser = nil
        isAuthenticated = false
        logger.info("User logged out")
    }

    func handleError(_ error: Error) {
        if let appError = error as? AppError {
            globalError = appError
        } else {
            globalError = AppError.unknown(error.localizedDescription)
        }
        logger.error("App error: \(error.localizedDescription)")
    }

    func clearError() {
        globalError = nil
    }
}

// MARK: - App Tab Enum

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case newProject = "New Project"
    case projects = "Projects"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .newProject: return "plus.circle.fill"
        case .projects: return "folder.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .dashboard: return "Dashboard tab"
        case .newProject: return "Create new project"
        case .projects: return "View all projects"
        case .settings: return "App settings"
        }
    }
}

// MARK: - App Error

enum AppError: LocalizedError, Identifiable {
    case networkError(String)
    case apiError(String)
    case authError(String)
    case dataError(String)
    case unknown(String)

    var id: String { errorDescription ?? "unknown" }

    var errorDescription: String? {
        switch self {
        case .networkError(let message): return "Network Error: \(message)"
        case .apiError(let message): return "API Error: \(message)"
        case .authError(let message): return "Authentication Error: \(message)"
        case .dataError(let message): return "Data Error: \(message)"
        case .unknown(let message): return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .apiError:
            return "Please verify your API key in Settings."
        case .authError:
            return "Please log in again."
        case .dataError:
            return "Please try refreshing the data."
        case .unknown:
            return "Please try again later."
        }
    }
}

// MARK: - Dependency Injection Container

/// Dependency injection container for service resolution
@MainActor
@Observable
final class DIContainer {

    static let shared = DIContainer()

    // MARK: - Services

    let networkService: NetworkService
    let geminiService: GeminiAPIService
    let pdfService: PDFExportService
    let keyManager: APIKeyManager

    // MARK: - Mock Services (for testing/previews)

    let mockGeminiService: MockGeminiAPIService

    private init() {
        self.networkService = NetworkService()
        self.geminiService = GeminiAPIService()
        self.pdfService = PDFExportService()
        self.keyManager = APIKeyManager()
        self.mockGeminiService = MockGeminiAPIService()
    }

    // MARK: - Factory Methods

    func makeProjectViewModel(modelContext: ModelContext) -> ProjectViewModel {
        ProjectViewModel(
            modelContext: modelContext,
            geminiService: geminiService
        )
    }

    func makeDashboardViewModel(modelContext: ModelContext) -> DashboardViewModel {
        DashboardViewModel(modelContext: modelContext)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(keyManager: keyManager)
    }
}

// MARK: - Environment Keys

struct AppStateKey: EnvironmentKey {
    static let defaultValue = AppState.shared
}

struct DIContainerKey: EnvironmentKey {
    @MainActor static let defaultValue = DIContainer.shared
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }

    var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}
