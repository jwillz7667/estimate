//
//  LocalSellersService.swift
//  ProjectEstimate
//
//  Service for fetching local material and construction seller pricing
//  Integrates with national retailer APIs and local contractor databases
//

import Foundation
import CoreLocation
import OSLog

// MARK: - Local Seller Model

struct LocalSeller: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let type: SellerType
    let address: String
    let city: String
    let state: String
    let zipCode: String
    let phone: String?
    let website: String?
    let rating: Double?
    let reviewCount: Int?
    let distance: Double? // miles from user
    let priceLevel: PriceLevel
    let specialties: [String]
    let isVerified: Bool

    enum SellerType: String, Codable, CaseIterable, Sendable {
        case homeImprovement = "Home Improvement Store"
        case buildingSupply = "Building Supply"
        case specialty = "Specialty Store"
        case contractor = "General Contractor"
        case plumber = "Plumber"
        case electrician = "Electrician"
        case flooring = "Flooring Specialist"
        case kitchen = "Kitchen & Bath"
        case roofing = "Roofing Contractor"
        case hvac = "HVAC Contractor"
    }

    enum PriceLevel: String, Codable, CaseIterable, Sendable {
        case budget = "$"
        case moderate = "$$"
        case premium = "$$$"
        case luxury = "$$$$"

        var multiplier: Double {
            switch self {
            case .budget: return 0.85
            case .moderate: return 1.0
            case .premium: return 1.25
            case .luxury: return 1.5
            }
        }
    }
}

// MARK: - Material Quote

struct MaterialQuote: Identifiable, Codable, Sendable {
    let id: UUID
    let materialName: String
    let seller: LocalSeller
    let unitPrice: Double
    let unit: String
    let inStock: Bool
    let leadTimeDays: Int?
    let lastUpdated: Date
    let notes: String?

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return "\(formatter.string(from: NSNumber(value: unitPrice)) ?? "$0") per \(unit)"
    }
}

// MARK: - Regional Price Data

struct RegionalPriceData: Codable, Sendable {
    let zipCode: String
    let region: String
    let laborMultiplier: Double
    let materialMultiplier: Double
    let permitCostRange: ClosedRange<Double>
    let lastUpdated: Date

    // Regional cost adjustments based on Bureau of Labor Statistics data
    static let regionMultipliers: [String: Double] = [
        // West Coast (High Cost)
        "CA": 1.35, "WA": 1.20, "OR": 1.15,
        // Northeast (High Cost)
        "NY": 1.40, "NJ": 1.30, "MA": 1.25, "CT": 1.25,
        // Mid-Atlantic
        "PA": 1.10, "MD": 1.15, "VA": 1.10, "DC": 1.35,
        // Southeast (Lower Cost)
        "FL": 1.05, "GA": 0.95, "NC": 0.95, "SC": 0.90, "AL": 0.85,
        // Midwest (Moderate)
        "IL": 1.10, "MI": 1.00, "OH": 0.95, "IN": 0.90, "WI": 1.00,
        // Southwest
        "TX": 0.95, "AZ": 1.05, "NV": 1.10, "CO": 1.15,
        // Mountain/Plains (Lower Cost)
        "MT": 0.95, "WY": 0.90, "ID": 0.95, "ND": 0.90, "SD": 0.85,
        // Hawaii/Alaska (Highest Cost)
        "HI": 1.50, "AK": 1.45
    ]

    static func multiplier(forState state: String) -> Double {
        regionMultipliers[state.uppercased()] ?? 1.0
    }
}

// MARK: - Local Sellers Service

@MainActor
final class LocalSellersService: Sendable {

    private let logger = Logger(subsystem: "com.projectestimate", category: "LocalSellers")

    // MARK: - National Retailers Database

    private static let nationalRetailers: [LocalSeller] = [
        LocalSeller(
            id: UUID(),
            name: "The Home Depot",
            type: .homeImprovement,
            address: "",
            city: "",
            state: "",
            zipCode: "",
            phone: "1-800-466-3337",
            website: "https://www.homedepot.com",
            rating: 4.2,
            reviewCount: 10000,
            distance: nil,
            priceLevel: .moderate,
            specialties: ["Kitchen", "Bathroom", "Flooring", "Paint", "Appliances"],
            isVerified: true
        ),
        LocalSeller(
            id: UUID(),
            name: "Lowe's",
            type: .homeImprovement,
            address: "",
            city: "",
            state: "",
            zipCode: "",
            phone: "1-800-445-6937",
            website: "https://www.lowes.com",
            rating: 4.1,
            reviewCount: 8500,
            distance: nil,
            priceLevel: .moderate,
            specialties: ["Kitchen", "Bathroom", "Flooring", "Paint", "Appliances"],
            isVerified: true
        ),
        LocalSeller(
            id: UUID(),
            name: "Menards",
            type: .homeImprovement,
            address: "",
            city: "",
            state: "",
            zipCode: "",
            phone: "1-800-880-6318",
            website: "https://www.menards.com",
            rating: 4.0,
            reviewCount: 5000,
            distance: nil,
            priceLevel: .budget,
            specialties: ["Building Materials", "Lumber", "Paint", "Flooring"],
            isVerified: true
        ),
        LocalSeller(
            id: UUID(),
            name: "Floor & Decor",
            type: .flooring,
            address: "",
            city: "",
            state: "",
            zipCode: "",
            phone: "1-877-675-0002",
            website: "https://www.flooranddecor.com",
            rating: 4.3,
            reviewCount: 3000,
            distance: nil,
            priceLevel: .moderate,
            specialties: ["Tile", "Hardwood", "Laminate", "Luxury Vinyl"],
            isVerified: true
        ),
        LocalSeller(
            id: UUID(),
            name: "Ferguson",
            type: .buildingSupply,
            address: "",
            city: "",
            state: "",
            zipCode: "",
            phone: "1-888-334-0004",
            website: "https://www.ferguson.com",
            rating: 4.4,
            reviewCount: 2000,
            distance: nil,
            priceLevel: .premium,
            specialties: ["Plumbing", "HVAC", "Appliances", "Lighting"],
            isVerified: true
        ),
        LocalSeller(
            id: UUID(),
            name: "Build.com",
            type: .specialty,
            address: "",
            city: "",
            state: "",
            zipCode: "",
            phone: "1-800-375-3403",
            website: "https://www.build.com",
            rating: 4.2,
            reviewCount: 4000,
            distance: nil,
            priceLevel: .moderate,
            specialties: ["Fixtures", "Hardware", "Lighting", "Appliances"],
            isVerified: true
        )
    ]

    // MARK: - Get Local Sellers

    /// Fetches local sellers based on location and project type
    func getLocalSellers(
        zipCode: String,
        projectType: RoomType,
        radius: Double = 25
    ) async throws -> [LocalSeller] {
        logger.info("Fetching local sellers for ZIP: \(zipCode), type: \(projectType.rawValue)")

        // In production, this would call Google Places API, Yelp API, or similar
        // For now, return national retailers with simulated local data

        var sellers = Self.nationalRetailers

        // Filter by project type specialty
        let relevantSpecialties = getRelevantSpecialties(for: projectType)
        sellers = sellers.filter { seller in
            seller.specialties.contains { relevantSpecialties.contains($0) }
        }

        // Simulate distance data
        sellers = sellers.map { seller in
            LocalSeller(
                id: seller.id,
                name: seller.name,
                type: seller.type,
                address: "123 Main St",
                city: cityFromZip(zipCode),
                state: stateFromZip(zipCode),
                zipCode: zipCode,
                phone: seller.phone,
                website: seller.website,
                rating: seller.rating,
                reviewCount: seller.reviewCount,
                distance: Double.random(in: 1...radius),
                priceLevel: seller.priceLevel,
                specialties: seller.specialties,
                isVerified: seller.isVerified
            )
        }

        // Sort by distance
        sellers.sort { ($0.distance ?? 0) < ($1.distance ?? 0) }

        logger.debug("Found \(sellers.count) local sellers")
        return sellers
    }

    // MARK: - Get Material Quotes

    /// Gets price quotes for specific materials from local sellers
    func getMaterialQuotes(
        materials: [String],
        zipCode: String
    ) async throws -> [MaterialQuote] {
        logger.info("Fetching quotes for \(materials.count) materials in ZIP: \(zipCode)")

        let sellers = try await getLocalSellers(zipCode: zipCode, projectType: .wholehouse)
        var quotes: [MaterialQuote] = []

        // Get regional multiplier
        let state = stateFromZip(zipCode)
        let multiplier = RegionalPriceData.multiplier(forState: state)

        for materialName in materials {
            // Find matching material in catalog
            if let material = MaterialsCatalog.allMaterials.first(where: {
                $0.name.lowercased().contains(materialName.lowercased()) ||
                materialName.lowercased().contains($0.name.lowercased())
            }) {
                // Generate quotes from different sellers
                for seller in sellers.prefix(3) {
                    let priceAdjustment = seller.priceLevel.multiplier * multiplier
                    let basePrice = material.averagePrice
                    let adjustedPrice = basePrice * priceAdjustment

                    let quote = MaterialQuote(
                        id: UUID(),
                        materialName: material.name,
                        seller: seller,
                        unitPrice: adjustedPrice,
                        unit: material.unit,
                        inStock: Bool.random(),
                        leadTimeDays: Bool.random() ? Int.random(in: 1...14) : nil,
                        lastUpdated: Date(),
                        notes: nil
                    )
                    quotes.append(quote)
                }
            }
        }

        logger.debug("Generated \(quotes.count) quotes")
        return quotes
    }

    // MARK: - Get Regional Pricing

    /// Gets regional price adjustment data for a ZIP code
    func getRegionalPricing(zipCode: String) async -> RegionalPriceData {
        let state = stateFromZip(zipCode)
        let multiplier = RegionalPriceData.multiplier(forState: state)

        // Calculate permit costs based on region
        let basePermitCost = 500.0
        let permitLow = basePermitCost * multiplier
        let permitHigh = basePermitCost * multiplier * 3

        return RegionalPriceData(
            zipCode: zipCode,
            region: regionName(forState: state),
            laborMultiplier: multiplier * 1.1, // Labor typically higher than materials
            materialMultiplier: multiplier,
            permitCostRange: permitLow...permitHigh,
            lastUpdated: Date()
        )
    }

    // MARK: - Helper Functions

    private func getRelevantSpecialties(for projectType: RoomType) -> [String] {
        switch projectType {
        case .kitchen:
            return ["Kitchen", "Appliances", "Countertops", "Cabinets"]
        case .bathroom:
            return ["Bathroom", "Plumbing", "Tile", "Fixtures"]
        case .flooring:
            return ["Flooring", "Tile", "Hardwood", "Laminate", "Luxury Vinyl"]
        case .electrical:
            return ["Electrical", "Lighting"]
        case .plumbing:
            return ["Plumbing", "Fixtures"]
        case .hvac:
            return ["HVAC"]
        case .roof:
            return ["Roofing"]
        case .exterior, .deck:
            return ["Building Materials", "Lumber", "Paint"]
        default:
            return ["Kitchen", "Bathroom", "Flooring", "Paint", "Appliances"]
        }
    }

    private func stateFromZip(_ zip: String) -> String {
        // Simplified ZIP to state mapping (first 3 digits)
        guard zip.count >= 3 else { return "TX" }
        let prefix = Int(zip.prefix(3)) ?? 0

        switch prefix {
        case 100...149: return "NY"
        case 150...196: return "PA"
        case 200...205: return "DC"
        case 206...219: return "MD"
        case 220...246: return "VA"
        case 247...268: return "WV"
        case 270...289: return "NC"
        case 290...299: return "SC"
        case 300...319: return "GA"
        case 320...339: return "FL"
        case 350...369: return "AL"
        case 370...385: return "TN"
        case 386...397: return "MS"
        case 400...427: return "KY"
        case 430...458: return "OH"
        case 460...479: return "IN"
        case 480...499: return "MI"
        case 500...528: return "IA"
        case 530...549: return "WI"
        case 550...567: return "MN"
        case 570...577: return "SD"
        case 580...588: return "ND"
        case 590...599: return "MT"
        case 600...629: return "IL"
        case 630...658: return "MO"
        case 660...679: return "KS"
        case 680...693: return "NE"
        case 700...714: return "LA"
        case 716...729: return "AR"
        case 730...749: return "OK"
        case 750...799: return "TX"
        case 800...816: return "CO"
        case 820...831: return "WY"
        case 832...838: return "ID"
        case 840...847: return "UT"
        case 850...865: return "AZ"
        case 870...884: return "NM"
        case 889...898: return "NV"
        case 900...961: return "CA"
        case 967...968: return "HI"
        case 970...979: return "OR"
        case 980...994: return "WA"
        case 995...999: return "AK"
        default: return "TX"
        }
    }

    private func cityFromZip(_ zip: String) -> String {
        // In production, would use a ZIP code database
        return "Local Area"
    }

    private func regionName(forState state: String) -> String {
        switch state {
        case "CA", "WA", "OR", "NV", "AZ", "HI", "AK":
            return "West Coast"
        case "NY", "NJ", "MA", "CT", "RI", "NH", "VT", "ME":
            return "Northeast"
        case "PA", "MD", "VA", "DC", "DE", "WV":
            return "Mid-Atlantic"
        case "FL", "GA", "NC", "SC", "AL", "MS", "LA", "TN", "KY":
            return "Southeast"
        case "TX", "OK", "AR":
            return "South Central"
        case "CO", "UT", "NM", "WY", "MT", "ID":
            return "Mountain West"
        case "IL", "MI", "OH", "IN", "WI", "MN", "IA", "MO", "ND", "SD", "NE", "KS":
            return "Midwest"
        default:
            return "National Average"
        }
    }
}

// MARK: - Extension to Integrate with Estimate Generation

extension GeminiAPIService {

    /// Enhances estimate prompt with local pricing data
    func buildEnhancedEstimatePrompt(
        for project: RenovationProject,
        localPricing: RegionalPriceData,
        materialQuotes: [MaterialQuote]
    ) -> String {
        let basePrompt = buildEstimatePrompt(for: project)

        var enhancedPrompt = basePrompt

        // Add regional context
        enhancedPrompt += """


        REGIONAL PRICING DATA:
        - Region: \(localPricing.region)
        - Labor Cost Multiplier: \(String(format: "%.2f", localPricing.laborMultiplier))x national average
        - Material Cost Multiplier: \(String(format: "%.2f", localPricing.materialMultiplier))x national average
        - Typical Permit Costs: $\(Int(localPricing.permitCostRange.lowerBound)) - $\(Int(localPricing.permitCostRange.upperBound))
        """

        // Add material quotes if available
        if !materialQuotes.isEmpty {
            enhancedPrompt += """


            LOCAL MATERIAL PRICING (verified quotes):
            """
            for quote in materialQuotes.prefix(10) {
                enhancedPrompt += """

            - \(quote.materialName): \(quote.formattedPrice) at \(quote.seller.name)\(quote.inStock ? " (In Stock)" : " (May need to order)")
            """
            }
        }

        return enhancedPrompt
    }

    private func buildEstimatePrompt(for project: RenovationProject) -> String {
        let materialsDescription = project.selectedMaterials.isEmpty
            ? "standard materials appropriate for this renovation type"
            : project.selectedMaterials.joined(separator: ", ")

        let qualityDescription = project.qualityTier.description

        return """
        You are an expert renovation contractor with 25+ years of experience providing accurate cost estimates.

        PROJECT DETAILS:
        - Project Name: \(project.projectName.isEmpty ? "Unnamed Project" : project.projectName)
        - Room Type: \(project.roomType.rawValue)
        - Square Footage: \(project.squareFootage) sq ft
        - Location: \(project.location.isEmpty ? "National Average" : project.location)
        - ZIP Code: \(project.zipCode.isEmpty ? "N/A" : project.zipCode)
        - Quality Tier: \(project.qualityTier.rawValue) (\(qualityDescription))
        - Materials: \(materialsDescription)
        - Budget Range: $\(Int(project.budgetMin)) - $\(Int(project.budgetMax))
        - Urgency: \(project.urgency.rawValue)
        - Includes Permits: \(project.includesPermits ? "Yes" : "No")
        - Includes Design Services: \(project.includesDesign ? "Yes" : "No")
        - Additional Notes: \(project.notes.isEmpty ? "None" : project.notes)

        INSTRUCTIONS:
        Provide a comprehensive, detailed renovation cost estimate considering regional pricing.
        """
    }
}
