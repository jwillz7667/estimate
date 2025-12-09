//
//  User.swift
//  ProjectEstimate
//
//  User authentication and profile model
//  Supports email/password and OAuth authentication flows
//

import Foundation
import SwiftData

/// Represents an authenticated user
@Model
final class User {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Authentication
    var email: String
    var authProvider: AuthProvider
    var isEmailVerified: Bool

    // MARK: - Profile
    var displayName: String
    var companyName: String
    var phoneNumber: String
    var avatarURL: String?
    var avatarData: Data?

    // MARK: - Business Details
    var licenseNumber: String
    var serviceRegions: [String]
    var specializations: [String]

    // MARK: - Preferences
    var defaultQualityTier: QualityTier
    var prefersDarkMode: Bool?
    var measurementSystem: MeasurementSystemType

    // MARK: - Subscription
    var subscriptionTier: SubscriptionTier
    var subscriptionExpiresAt: Date?

    // MARK: - Usage Tracking
    var estimatesGeneratedThisMonth: Int
    var imagesGeneratedThisMonth: Int
    var lastActiveAt: Date

    init(
        id: UUID = UUID(),
        email: String = "",
        authProvider: AuthProvider = .email,
        isEmailVerified: Bool = false,
        displayName: String = "",
        companyName: String = "",
        phoneNumber: String = "",
        avatarURL: String? = nil,
        licenseNumber: String = "",
        serviceRegions: [String] = [],
        specializations: [String] = [],
        defaultQualityTier: QualityTier = .standard,
        prefersDarkMode: Bool? = nil,
        measurementSystem: MeasurementSystemType = .imperial,
        subscriptionTier: SubscriptionTier = .free,
        subscriptionExpiresAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = Date()
        self.updatedAt = Date()
        self.email = email
        self.authProvider = authProvider
        self.isEmailVerified = isEmailVerified
        self.displayName = displayName
        self.companyName = companyName
        self.phoneNumber = phoneNumber
        self.avatarURL = avatarURL
        self.licenseNumber = licenseNumber
        self.serviceRegions = serviceRegions
        self.specializations = specializations
        self.defaultQualityTier = defaultQualityTier
        self.prefersDarkMode = prefersDarkMode
        self.measurementSystem = measurementSystem
        self.subscriptionTier = subscriptionTier
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.estimatesGeneratedThisMonth = 0
        self.imagesGeneratedThisMonth = 0
        self.lastActiveAt = Date()
    }

    /// Checks if user can generate more estimates this month
    var canGenerateEstimate: Bool {
        estimatesGeneratedThisMonth < subscriptionTier.estimateLimit
    }

    /// Checks if user can generate more images this month
    var canGenerateImage: Bool {
        imagesGeneratedThisMonth < subscriptionTier.imageLimit
    }

    /// Remaining estimate credits
    var remainingEstimates: Int {
        max(0, subscriptionTier.estimateLimit - estimatesGeneratedThisMonth)
    }

    /// Remaining image credits
    var remainingImages: Int {
        max(0, subscriptionTier.imageLimit - imagesGeneratedThisMonth)
    }

    /// Formatted display name (company or personal)
    var formattedDisplayName: String {
        if !companyName.isEmpty {
            return companyName
        }
        return displayName.isEmpty ? email : displayName
    }
}

// MARK: - Enums

enum AuthProvider: String, Codable, CaseIterable, Sendable {
    case email = "email"
    case google = "google"
    case apple = "apple"

    var displayName: String {
        switch self {
        case .email: return "Email"
        case .google: return "Google"
        case .apple: return "Apple"
        }
    }

    var iconName: String {
        switch self {
        case .email: return "envelope.fill"
        case .google: return "g.circle.fill"
        case .apple: return "apple.logo"
        }
    }
}

enum MeasurementSystemType: String, Codable, CaseIterable, Sendable {
    case imperial = "Imperial (ft, in)"
    case metric = "Metric (m, cm)"

    var squareFootageLabel: String {
        switch self {
        case .imperial: return "sq ft"
        case .metric: return "sq m"
        }
    }

    var linearLabel: String {
        switch self {
        case .imperial: return "ft"
        case .metric: return "m"
        }
    }
}

enum SubscriptionTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case free = "Free"
    case professional = "Professional"
    case enterprise = "Enterprise"

    var id: String { rawValue }

    var estimateLimit: Int {
        switch self {
        case .free: return 5
        case .professional: return 100
        case .enterprise: return Int.max
        }
    }

    var imageLimit: Int {
        switch self {
        case .free: return 3
        case .professional: return 50
        case .enterprise: return Int.max
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "5 estimates per month",
                "3 image generations",
                "Basic materials library",
                "PDF export"
            ]
        case .professional:
            return [
                "100 estimates per month",
                "50 image generations",
                "Full materials library",
                "Priority AI processing",
                "Custom branding on PDFs",
                "Email support"
            ]
        case .enterprise:
            return [
                "Unlimited estimates",
                "Unlimited image generations",
                "Full materials library",
                "Priority AI processing",
                "Custom branding",
                "API access",
                "Multi-user accounts",
                "Dedicated support",
                "Custom integrations"
            ]
        }
    }

    var monthlyPrice: Double {
        switch self {
        case .free: return 0
        case .professional: return 49.99
        case .enterprise: return 199.99
        }
    }

    var annualPrice: Double {
        switch self {
        case .free: return 0
        case .professional: return 499.99
        case .enterprise: return 1999.99
        }
    }
}
