//
//  RenovationProject.swift
//  ProjectEstimate
//
//  Enterprise-grade renovation project model with comprehensive property tracking
//  Architecture: SwiftData model with Codable conformance for API serialization
//

import Foundation
import SwiftData

/// Represents a complete renovation project with all input parameters
/// Used for both local persistence and API request construction
@Model
final class RenovationProject: @unchecked Sendable {
    // MARK: - Identifiers
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Project Details
    var projectName: String
    var roomType: RoomType
    var squareFootage: Double
    var location: String
    var zipCode: String

    // MARK: - Budget & Materials
    var budgetMin: Double
    var budgetMax: Double
    var selectedMaterials: [String]
    var qualityTier: QualityTier

    // MARK: - Additional Details
    var notes: String
    var urgency: ProjectUrgency
    var includesPermits: Bool
    var includesDesign: Bool

    // MARK: - Uploaded Images
    /// User-uploaded photos of the area to be renovated
    @Attribute(.externalStorage) var uploadedImageData: [Data] = []
    /// Text description of desired renovations
    var renovationDescription: String = ""

    // MARK: - Status
    var status: ProjectStatus

    // MARK: - Relationships
    @Relationship(deleteRule: .cascade)
    var estimates: [EstimateResult]?

    @Relationship(deleteRule: .cascade)
    var generatedImages: [GeneratedImage]?

    init(
        id: UUID = UUID(),
        projectName: String = "",
        roomType: RoomType = .kitchen,
        squareFootage: Double = 0,
        location: String = "",
        zipCode: String = "",
        budgetMin: Double = 0,
        budgetMax: Double = 0,
        selectedMaterials: [String] = [],
        qualityTier: QualityTier = .standard,
        notes: String = "",
        urgency: ProjectUrgency = .standard,
        includesPermits: Bool = true,
        includesDesign: Bool = false,
        uploadedImageData: [Data] = [],
        renovationDescription: String = "",
        status: ProjectStatus = .draft
    ) {
        self.id = id
        self.createdAt = Date()
        self.updatedAt = Date()
        self.projectName = projectName
        self.roomType = roomType
        self.squareFootage = squareFootage
        self.location = location
        self.zipCode = zipCode
        self.budgetMin = budgetMin
        self.budgetMax = budgetMax
        self.selectedMaterials = selectedMaterials
        self.qualityTier = qualityTier
        self.notes = notes
        self.urgency = urgency
        self.includesPermits = includesPermits
        self.includesDesign = includesDesign
        self.uploadedImageData = uploadedImageData
        self.renovationDescription = renovationDescription
        self.status = status
    }
}

// MARK: - Enums

enum RoomType: String, Codable, CaseIterable, Identifiable, Sendable {
    case kitchen = "Kitchen"
    case bathroom = "Bathroom"
    case bedroom = "Bedroom"
    case livingRoom = "Living Room"
    case basement = "Basement"
    case attic = "Attic"
    case garage = "Garage"
    case deck = "Deck/Patio"
    case wholehouse = "Whole House"
    case addition = "Addition"
    case exterior = "Exterior"
    case roof = "Roof"
    case flooring = "Flooring Only"
    case electrical = "Electrical"
    case plumbing = "Plumbing"
    case hvac = "HVAC"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .kitchen: return "frying.pan"
        case .bathroom: return "shower"
        case .bedroom: return "bed.double"
        case .livingRoom: return "sofa"
        case .basement: return "stairs"
        case .attic: return "house.lodge"
        case .garage: return "car"
        case .deck: return "tree"
        case .wholehouse: return "house"
        case .addition: return "plus.rectangle.on.rectangle"
        case .exterior: return "building.2"
        case .roof: return "house.and.flag"
        case .flooring: return "square.grid.3x3"
        case .electrical: return "bolt"
        case .plumbing: return "pipe.and.drop"
        case .hvac: return "air.conditioner.horizontal"
        }
    }

    /// Realistic 2024-2025 cost per sq ft ranges based on industry data
    /// Sources: HomeAdvisor, Angi, Remodeling Magazine Cost vs Value Report
    var averageCostPerSqFt: ClosedRange<Double> {
        switch self {
        case .kitchen: return 75...200          // Minor: $75-125, Major: $150-200+
        case .bathroom: return 70...175         // Half bath: $70-100, Full: $100-175
        case .bedroom: return 25...75           // Paint/flooring: $25-50, Full remodel: $50-75
        case .livingRoom: return 20...60        // Cosmetic: $20-35, Full: $40-60
        case .basement: return 25...60          // Basic finish: $25-35, Full: $40-60
        case .attic: return 40...80             // Basic conversion: $40-55, Full: $60-80
        case .garage: return 15...40            // Basic: $15-25, Workshop conversion: $30-40
        case .deck: return 15...45              // Wood: $15-25, Composite: $30-45
        case .wholehouse: return 50...150       // Cosmetic: $50-75, Major: $100-150
        case .addition: return 80...200         // Basic: $80-120, High-end: $150-200
        case .exterior: return 10...30          // Siding/paint only: $10-20, Full: $20-30
        case .roof: return 4...12               // Asphalt: $4-7, Metal/tile: $8-12
        case .flooring: return 5...18           // LVP: $5-8, Hardwood: $10-18
        case .electrical: return 6...15         // Minor: $6-10, Rewire: $10-15
        case .plumbing: return 10...35          // Fixture replace: $10-20, Repipe: $25-35
        case .hvac: return 20...45              // Replace: $20-30, New system: $35-45
        }
    }
}

enum QualityTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case economy = "Economy"
    case standard = "Standard"
    case premium = "Premium"
    case luxury = "Luxury"

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .economy: return 0.7
        case .standard: return 1.0
        case .premium: return 1.5
        case .luxury: return 2.5
        }
    }

    var description: String {
        switch self {
        case .economy: return "Basic materials, minimal customization"
        case .standard: return "Mid-range materials, standard finishes"
        case .premium: return "High-quality materials, upgraded features"
        case .luxury: return "Top-tier materials, custom craftsmanship"
        }
    }
}

enum ProjectUrgency: String, Codable, CaseIterable, Identifiable, Sendable {
    case flexible = "Flexible Timeline"
    case standard = "Standard (2-4 weeks)"
    case rush = "Rush (1-2 weeks)"
    case emergency = "Emergency (ASAP)"

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .flexible: return 0.95
        case .standard: return 1.0
        case .rush: return 1.25
        case .emergency: return 1.5
        }
    }
}

enum ProjectStatus: String, Codable, CaseIterable, Sendable {
    case draft = "Draft"
    case estimating = "Estimating"
    case estimated = "Estimated"
    case approved = "Approved"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"

    var color: String {
        switch self {
        case .draft: return "gray"
        case .estimating: return "orange"
        case .estimated: return "blue"
        case .approved: return "green"
        case .inProgress: return "purple"
        case .completed: return "teal"
        case .cancelled: return "red"
        }
    }
}
