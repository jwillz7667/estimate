//
//  MaterialsCatalog.swift
//  ProjectEstimate
//
//  Comprehensive materials catalog with pricing data
//  Used for autocomplete suggestions and cost calculations
//

import Foundation

/// Materials catalog with categorized renovation materials
struct MaterialsCatalog: Sendable {

    // MARK: - Kitchen Materials

    static let kitchenMaterials: [MaterialItem] = [
        // Countertops
        MaterialItem(name: "Granite Countertop", category: "Countertops", pricePerUnit: 60...120, unit: "sq ft"),
        MaterialItem(name: "Quartz Countertop", category: "Countertops", pricePerUnit: 75...150, unit: "sq ft"),
        MaterialItem(name: "Marble Countertop", category: "Countertops", pricePerUnit: 100...200, unit: "sq ft"),
        MaterialItem(name: "Butcher Block Countertop", category: "Countertops", pricePerUnit: 40...80, unit: "sq ft"),
        MaterialItem(name: "Laminate Countertop", category: "Countertops", pricePerUnit: 15...40, unit: "sq ft"),
        MaterialItem(name: "Concrete Countertop", category: "Countertops", pricePerUnit: 70...150, unit: "sq ft"),

        // Cabinets
        MaterialItem(name: "Stock Cabinets", category: "Cabinets", pricePerUnit: 100...300, unit: "linear ft"),
        MaterialItem(name: "Semi-Custom Cabinets", category: "Cabinets", pricePerUnit: 200...600, unit: "linear ft"),
        MaterialItem(name: "Custom Cabinets", category: "Cabinets", pricePerUnit: 500...1500, unit: "linear ft"),
        MaterialItem(name: "RTA Cabinets", category: "Cabinets", pricePerUnit: 75...200, unit: "linear ft"),

        // Appliances
        MaterialItem(name: "Refrigerator (Standard)", category: "Appliances", pricePerUnit: 800...2000, unit: "unit"),
        MaterialItem(name: "Refrigerator (Premium)", category: "Appliances", pricePerUnit: 2000...5000, unit: "unit"),
        MaterialItem(name: "Range/Oven (Gas)", category: "Appliances", pricePerUnit: 600...2500, unit: "unit"),
        MaterialItem(name: "Range/Oven (Electric)", category: "Appliances", pricePerUnit: 500...2000, unit: "unit"),
        MaterialItem(name: "Dishwasher", category: "Appliances", pricePerUnit: 400...1200, unit: "unit"),
        MaterialItem(name: "Microwave (Built-in)", category: "Appliances", pricePerUnit: 300...800, unit: "unit"),
        MaterialItem(name: "Range Hood", category: "Appliances", pricePerUnit: 200...1500, unit: "unit"),

        // Backsplash
        MaterialItem(name: "Ceramic Tile Backsplash", category: "Backsplash", pricePerUnit: 10...30, unit: "sq ft"),
        MaterialItem(name: "Glass Tile Backsplash", category: "Backsplash", pricePerUnit: 25...50, unit: "sq ft"),
        MaterialItem(name: "Natural Stone Backsplash", category: "Backsplash", pricePerUnit: 30...75, unit: "sq ft"),
        MaterialItem(name: "Metal Backsplash", category: "Backsplash", pricePerUnit: 20...60, unit: "sq ft"),

        // Fixtures
        MaterialItem(name: "Kitchen Sink (Stainless)", category: "Fixtures", pricePerUnit: 200...600, unit: "unit"),
        MaterialItem(name: "Kitchen Sink (Composite)", category: "Fixtures", pricePerUnit: 300...800, unit: "unit"),
        MaterialItem(name: "Kitchen Faucet (Standard)", category: "Fixtures", pricePerUnit: 150...400, unit: "unit"),
        MaterialItem(name: "Kitchen Faucet (Premium)", category: "Fixtures", pricePerUnit: 400...1000, unit: "unit")
    ]

    // MARK: - Bathroom Materials

    static let bathroomMaterials: [MaterialItem] = [
        // Fixtures
        MaterialItem(name: "Toilet (Standard)", category: "Fixtures", pricePerUnit: 150...400, unit: "unit"),
        MaterialItem(name: "Toilet (Premium/Smart)", category: "Fixtures", pricePerUnit: 500...2000, unit: "unit"),
        MaterialItem(name: "Vanity (Single)", category: "Fixtures", pricePerUnit: 200...800, unit: "unit"),
        MaterialItem(name: "Vanity (Double)", category: "Fixtures", pricePerUnit: 400...1500, unit: "unit"),
        MaterialItem(name: "Bathtub (Standard)", category: "Fixtures", pricePerUnit: 300...800, unit: "unit"),
        MaterialItem(name: "Bathtub (Freestanding)", category: "Fixtures", pricePerUnit: 800...3000, unit: "unit"),
        MaterialItem(name: "Shower Door (Frameless)", category: "Fixtures", pricePerUnit: 500...1500, unit: "unit"),
        MaterialItem(name: "Shower Door (Framed)", category: "Fixtures", pricePerUnit: 200...600, unit: "unit"),
        MaterialItem(name: "Walk-in Shower Kit", category: "Fixtures", pricePerUnit: 1000...3000, unit: "unit"),

        // Tile
        MaterialItem(name: "Ceramic Floor Tile", category: "Tile", pricePerUnit: 3...10, unit: "sq ft"),
        MaterialItem(name: "Porcelain Floor Tile", category: "Tile", pricePerUnit: 5...15, unit: "sq ft"),
        MaterialItem(name: "Natural Stone Tile", category: "Tile", pricePerUnit: 15...40, unit: "sq ft"),
        MaterialItem(name: "Wall Tile", category: "Tile", pricePerUnit: 5...20, unit: "sq ft"),
        MaterialItem(name: "Mosaic Tile", category: "Tile", pricePerUnit: 15...50, unit: "sq ft"),

        // Countertops
        MaterialItem(name: "Bathroom Vanity Top (Granite)", category: "Countertops", pricePerUnit: 200...600, unit: "unit"),
        MaterialItem(name: "Bathroom Vanity Top (Quartz)", category: "Countertops", pricePerUnit: 250...700, unit: "unit"),
        MaterialItem(name: "Bathroom Vanity Top (Marble)", category: "Countertops", pricePerUnit: 300...900, unit: "unit")
    ]

    // MARK: - Flooring Materials

    static let flooringMaterials: [MaterialItem] = [
        MaterialItem(name: "Hardwood Flooring (Oak)", category: "Hardwood", pricePerUnit: 6...12, unit: "sq ft"),
        MaterialItem(name: "Hardwood Flooring (Maple)", category: "Hardwood", pricePerUnit: 7...14, unit: "sq ft"),
        MaterialItem(name: "Hardwood Flooring (Walnut)", category: "Hardwood", pricePerUnit: 10...18, unit: "sq ft"),
        MaterialItem(name: "Engineered Hardwood", category: "Hardwood", pricePerUnit: 4...10, unit: "sq ft"),
        MaterialItem(name: "Laminate Flooring", category: "Laminate", pricePerUnit: 2...6, unit: "sq ft"),
        MaterialItem(name: "Luxury Vinyl Plank (LVP)", category: "Vinyl", pricePerUnit: 3...8, unit: "sq ft"),
        MaterialItem(name: "Luxury Vinyl Tile (LVT)", category: "Vinyl", pricePerUnit: 3...8, unit: "sq ft"),
        MaterialItem(name: "Sheet Vinyl", category: "Vinyl", pricePerUnit: 1...4, unit: "sq ft"),
        MaterialItem(name: "Ceramic Tile", category: "Tile", pricePerUnit: 3...10, unit: "sq ft"),
        MaterialItem(name: "Porcelain Tile", category: "Tile", pricePerUnit: 5...15, unit: "sq ft"),
        MaterialItem(name: "Natural Stone (Slate)", category: "Stone", pricePerUnit: 10...25, unit: "sq ft"),
        MaterialItem(name: "Natural Stone (Travertine)", category: "Stone", pricePerUnit: 8...20, unit: "sq ft"),
        MaterialItem(name: "Carpet (Standard)", category: "Carpet", pricePerUnit: 2...5, unit: "sq ft"),
        MaterialItem(name: "Carpet (Premium)", category: "Carpet", pricePerUnit: 5...12, unit: "sq ft"),
        MaterialItem(name: "Cork Flooring", category: "Alternative", pricePerUnit: 4...10, unit: "sq ft"),
        MaterialItem(name: "Bamboo Flooring", category: "Alternative", pricePerUnit: 4...9, unit: "sq ft"),
        MaterialItem(name: "Concrete (Polished)", category: "Alternative", pricePerUnit: 3...8, unit: "sq ft")
    ]

    // MARK: - General Materials

    static let generalMaterials: [MaterialItem] = [
        // Drywall
        MaterialItem(name: "Drywall (1/2\")", category: "Drywall", pricePerUnit: 12...20, unit: "4x8 sheet"),
        MaterialItem(name: "Drywall (5/8\" Fire-Rated)", category: "Drywall", pricePerUnit: 15...25, unit: "4x8 sheet"),
        MaterialItem(name: "Moisture-Resistant Drywall", category: "Drywall", pricePerUnit: 18...28, unit: "4x8 sheet"),

        // Paint
        MaterialItem(name: "Interior Paint (Standard)", category: "Paint", pricePerUnit: 25...40, unit: "gallon"),
        MaterialItem(name: "Interior Paint (Premium)", category: "Paint", pricePerUnit: 40...70, unit: "gallon"),
        MaterialItem(name: "Exterior Paint", category: "Paint", pricePerUnit: 35...60, unit: "gallon"),
        MaterialItem(name: "Primer", category: "Paint", pricePerUnit: 20...35, unit: "gallon"),

        // Trim & Molding
        MaterialItem(name: "Baseboard (MDF)", category: "Trim", pricePerUnit: 1...3, unit: "linear ft"),
        MaterialItem(name: "Baseboard (Wood)", category: "Trim", pricePerUnit: 2...6, unit: "linear ft"),
        MaterialItem(name: "Crown Molding (MDF)", category: "Trim", pricePerUnit: 2...4, unit: "linear ft"),
        MaterialItem(name: "Crown Molding (Wood)", category: "Trim", pricePerUnit: 4...10, unit: "linear ft"),
        MaterialItem(name: "Door Casing", category: "Trim", pricePerUnit: 1...3, unit: "linear ft"),
        MaterialItem(name: "Window Casing", category: "Trim", pricePerUnit: 1...3, unit: "linear ft"),

        // Doors
        MaterialItem(name: "Interior Door (Hollow Core)", category: "Doors", pricePerUnit: 50...100, unit: "unit"),
        MaterialItem(name: "Interior Door (Solid Core)", category: "Doors", pricePerUnit: 150...400, unit: "unit"),
        MaterialItem(name: "Exterior Door (Steel)", category: "Doors", pricePerUnit: 200...600, unit: "unit"),
        MaterialItem(name: "Exterior Door (Fiberglass)", category: "Doors", pricePerUnit: 400...1200, unit: "unit"),
        MaterialItem(name: "Exterior Door (Wood)", category: "Doors", pricePerUnit: 500...2000, unit: "unit"),
        MaterialItem(name: "Sliding Glass Door", category: "Doors", pricePerUnit: 600...2000, unit: "unit"),
        MaterialItem(name: "French Doors", category: "Doors", pricePerUnit: 800...2500, unit: "pair"),

        // Windows
        MaterialItem(name: "Vinyl Window (Double-Hung)", category: "Windows", pricePerUnit: 200...500, unit: "unit"),
        MaterialItem(name: "Wood Window", category: "Windows", pricePerUnit: 400...1000, unit: "unit"),
        MaterialItem(name: "Casement Window", category: "Windows", pricePerUnit: 300...700, unit: "unit"),
        MaterialItem(name: "Picture Window", category: "Windows", pricePerUnit: 400...1200, unit: "unit"),
        MaterialItem(name: "Skylight", category: "Windows", pricePerUnit: 500...2000, unit: "unit"),

        // Electrical
        MaterialItem(name: "Electrical Outlet", category: "Electrical", pricePerUnit: 3...10, unit: "unit"),
        MaterialItem(name: "Light Switch", category: "Electrical", pricePerUnit: 3...15, unit: "unit"),
        MaterialItem(name: "GFCI Outlet", category: "Electrical", pricePerUnit: 15...30, unit: "unit"),
        MaterialItem(name: "Recessed Light", category: "Electrical", pricePerUnit: 30...100, unit: "unit"),
        MaterialItem(name: "Ceiling Fan", category: "Electrical", pricePerUnit: 100...500, unit: "unit"),
        MaterialItem(name: "Chandelier", category: "Electrical", pricePerUnit: 150...2000, unit: "unit"),

        // Plumbing
        MaterialItem(name: "PEX Pipe", category: "Plumbing", pricePerUnit: 0.5...2, unit: "linear ft"),
        MaterialItem(name: "Copper Pipe", category: "Plumbing", pricePerUnit: 2...5, unit: "linear ft"),
        MaterialItem(name: "Water Heater (Tank)", category: "Plumbing", pricePerUnit: 600...1500, unit: "unit"),
        MaterialItem(name: "Water Heater (Tankless)", category: "Plumbing", pricePerUnit: 1000...3000, unit: "unit")
    ]

    // MARK: - All Materials

    static var allMaterials: [MaterialItem] {
        kitchenMaterials + bathroomMaterials + flooringMaterials + generalMaterials
    }

    /// Returns materials filtered by room type
    static func materials(for roomType: RoomType) -> [MaterialItem] {
        switch roomType {
        case .kitchen:
            return kitchenMaterials + flooringMaterials.filter { $0.category != "Carpet" } + generalMaterials
        case .bathroom:
            return bathroomMaterials + generalMaterials.filter { !["Carpet", "Doors"].contains($0.category) }
        case .flooring:
            return flooringMaterials + generalMaterials.filter { $0.category == "Trim" }
        case .bedroom, .livingRoom:
            return flooringMaterials + generalMaterials
        case .basement:
            return flooringMaterials + generalMaterials + bathroomMaterials
        case .exterior, .deck, .roof:
            return generalMaterials.filter { ["Doors", "Windows", "Paint"].contains($0.category) }
        default:
            return allMaterials
        }
    }

    /// Searches materials by name
    static func search(_ query: String) -> [MaterialItem] {
        guard !query.isEmpty else { return allMaterials }
        let lowercased = query.lowercased()
        return allMaterials.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.category.lowercased().contains(lowercased)
        }
    }
}

// MARK: - Material Item Model

struct MaterialItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let category: String
    let pricePerUnit: ClosedRange<Double>
    let unit: String

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        pricePerUnit: ClosedRange<Double>,
        unit: String
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.pricePerUnit = pricePerUnit
        self.unit = unit
    }

    var averagePrice: Double {
        (pricePerUnit.lowerBound + pricePerUnit.upperBound) / 2
    }

    var formattedPriceRange: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        let low = formatter.string(from: NSNumber(value: pricePerUnit.lowerBound)) ?? "$0"
        let high = formatter.string(from: NSNumber(value: pricePerUnit.upperBound)) ?? "$0"
        return "\(low) - \(high) per \(unit)"
    }
}
