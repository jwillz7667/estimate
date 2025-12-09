//
//  EstimateResult.swift
//  ProjectEstimate
//
//  Comprehensive estimate result model with detailed cost breakdown
//  Designed for Gemini API response parsing and local persistence
//

import Foundation
import SwiftData

/// Complete estimate result from AI analysis
/// Contains itemized costs, timeline, and recommendations
@Model
final class EstimateResult: @unchecked Sendable {
    var id: UUID
    var createdAt: Date

    // MARK: - Cost Summary
    var totalCostLow: Double
    var totalCostHigh: Double
    var confidenceScore: Double

    // MARK: - Breakdown
    var laborCost: Double
    var materialsCost: Double
    var permitsCost: Double
    var designCost: Double
    var contingencyCost: Double
    var overheadCost: Double

    // MARK: - Timeline
    var estimatedDaysLow: Int
    var estimatedDaysHigh: Int
    var recommendedStartSeason: String

    // MARK: - Details
    var lineItems: [EstimateLineItem]
    var notes: String
    var warnings: [String]
    var recommendations: [String]

    // MARK: - Regional Data
    var regionMultiplier: Double
    var regionName: String

    // MARK: - Raw Response
    var rawAPIResponse: String?

    // MARK: - Relationship
    var project: RenovationProject?

    init(
        id: UUID = UUID(),
        totalCostLow: Double = 0,
        totalCostHigh: Double = 0,
        confidenceScore: Double = 0,
        laborCost: Double = 0,
        materialsCost: Double = 0,
        permitsCost: Double = 0,
        designCost: Double = 0,
        contingencyCost: Double = 0,
        overheadCost: Double = 0,
        estimatedDaysLow: Int = 0,
        estimatedDaysHigh: Int = 0,
        recommendedStartSeason: String = "",
        lineItems: [EstimateLineItem] = [],
        notes: String = "",
        warnings: [String] = [],
        recommendations: [String] = [],
        regionMultiplier: Double = 1.0,
        regionName: String = "",
        rawAPIResponse: String? = nil
    ) {
        self.id = id
        self.createdAt = Date()
        self.totalCostLow = totalCostLow
        self.totalCostHigh = totalCostHigh
        self.confidenceScore = confidenceScore
        self.laborCost = laborCost
        self.materialsCost = materialsCost
        self.permitsCost = permitsCost
        self.designCost = designCost
        self.contingencyCost = contingencyCost
        self.overheadCost = overheadCost
        self.estimatedDaysLow = estimatedDaysLow
        self.estimatedDaysHigh = estimatedDaysHigh
        self.recommendedStartSeason = recommendedStartSeason
        self.lineItems = lineItems
        self.notes = notes
        self.warnings = warnings
        self.recommendations = recommendations
        self.regionMultiplier = regionMultiplier
        self.regionName = regionName
        self.rawAPIResponse = rawAPIResponse
    }

    /// Formatted total cost range string
    var formattedTotalRange: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        let low = formatter.string(from: NSNumber(value: totalCostLow)) ?? "$0"
        let high = formatter.string(from: NSNumber(value: totalCostHigh)) ?? "$0"
        return "\(low) - \(high)"
    }

    /// Average total cost
    var averageTotalCost: Double {
        (totalCostLow + totalCostHigh) / 2
    }

    /// Formatted timeline string
    var formattedTimeline: String {
        if estimatedDaysLow == estimatedDaysHigh {
            return "\(estimatedDaysLow) days"
        }
        return "\(estimatedDaysLow) - \(estimatedDaysHigh) days"
    }

    /// Cost breakdown for charts
    var costBreakdown: [(category: String, amount: Double, color: String)] {
        [
            ("Labor", laborCost, "blue"),
            ("Materials", materialsCost, "green"),
            ("Permits", permitsCost, "orange"),
            ("Design", designCost, "purple"),
            ("Contingency", contingencyCost, "red"),
            ("Overhead", overheadCost, "gray")
        ].filter { $0.amount > 0 }
    }
}

// MARK: - Line Item Model

/// Individual line item within an estimate
struct EstimateLineItem: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var category: String
    var itemName: String
    var description: String
    var quantity: Double
    var unit: String
    var unitCostLow: Double
    var unitCostHigh: Double
    var isOptional: Bool

    init(
        id: UUID = UUID(),
        category: String = "",
        itemName: String = "",
        description: String = "",
        quantity: Double = 1,
        unit: String = "each",
        unitCostLow: Double = 0,
        unitCostHigh: Double = 0,
        isOptional: Bool = false
    ) {
        self.id = id
        self.category = category
        self.itemName = itemName
        self.description = description
        self.quantity = quantity
        self.unit = unit
        self.unitCostLow = unitCostLow
        self.unitCostHigh = unitCostHigh
        self.isOptional = isOptional
    }

    var totalCostLow: Double { quantity * unitCostLow }
    var totalCostHigh: Double { quantity * unitCostHigh }

    var formattedCostRange: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        let low = formatter.string(from: NSNumber(value: totalCostLow)) ?? "$0"
        let high = formatter.string(from: NSNumber(value: totalCostHigh)) ?? "$0"
        return "\(low) - \(high)"
    }
}

// MARK: - API Response DTOs

/// DTO for parsing Gemini API response
struct GeminiEstimateResponse: Codable, Sendable {
    let totalCost: CostRange
    let breakdown: [BreakdownItem]
    let timeline: TimelineInfo
    let notes: String
    let warnings: [String]?
    let recommendations: [String]?
    let confidence: Double?
    let regionalData: RegionalData?

    struct CostRange: Codable, Sendable {
        let low: Double
        let high: Double
    }

    struct BreakdownItem: Codable, Sendable {
        let category: String
        let item: String
        let description: String
        let quantity: Double?
        let unit: String?
        let costLow: Double
        let costHigh: Double
        let optional: Bool?
    }

    struct TimelineInfo: Codable, Sendable {
        let daysLow: Int
        let daysHigh: Int
        let recommendedSeason: String?
    }

    struct RegionalData: Codable, Sendable {
        let multiplier: Double
        let region: String
    }
}

// MARK: - Estimate Conversion Extension

extension GeminiEstimateResponse {
    /// Converts API response to local model
    func toEstimateResult() -> EstimateResult {
        var laborTotal: Double = 0
        var materialsTotal: Double = 0
        var permitsTotal: Double = 0
        var designTotal: Double = 0
        var contingencyTotal: Double = 0
        var overheadTotal: Double = 0

        let lineItems: [EstimateLineItem] = breakdown.map { item in
            let avgCost = (item.costLow + item.costHigh) / 2

            switch item.category.lowercased() {
            case "labor", "labour": laborTotal += avgCost
            case "materials", "material": materialsTotal += avgCost
            case "permits", "permit": permitsTotal += avgCost
            case "design": designTotal += avgCost
            case "contingency": contingencyTotal += avgCost
            case "overhead", "margin": overheadTotal += avgCost
            default: materialsTotal += avgCost
            }

            return EstimateLineItem(
                category: item.category,
                itemName: item.item,
                description: item.description,
                quantity: item.quantity ?? 1,
                unit: item.unit ?? "each",
                unitCostLow: item.costLow,
                unitCostHigh: item.costHigh,
                isOptional: item.optional ?? false
            )
        }

        return EstimateResult(
            totalCostLow: totalCost.low,
            totalCostHigh: totalCost.high,
            confidenceScore: confidence ?? 0.85,
            laborCost: laborTotal,
            materialsCost: materialsTotal,
            permitsCost: permitsTotal,
            designCost: designTotal,
            contingencyCost: contingencyTotal,
            overheadCost: overheadTotal,
            estimatedDaysLow: timeline.daysLow,
            estimatedDaysHigh: timeline.daysHigh,
            recommendedStartSeason: timeline.recommendedSeason ?? "Any",
            lineItems: lineItems,
            notes: notes,
            warnings: warnings ?? [],
            recommendations: recommendations ?? [],
            regionMultiplier: regionalData?.multiplier ?? 1.0,
            regionName: regionalData?.region ?? "National Average"
        )
    }
}
