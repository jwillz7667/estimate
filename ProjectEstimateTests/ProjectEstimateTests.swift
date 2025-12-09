//
//  ProjectEstimateTests.swift
//  ProjectEstimateTests
//
//  Comprehensive unit tests for RenovationEstimator Pro
//  Covers Models, Services, and Core Business Logic
//

import Testing
import Foundation
@testable import ProjectEstimate

// MARK: - Model Tests

@Suite("Renovation Project Tests")
struct RenovationProjectTests {

    @Test("Project initialization with default values")
    func testProjectInitialization() {
        let project = RenovationProject(
            projectName: "Kitchen Reno",
            roomType: .kitchen,
            squareFootage: 200
        )

        #expect(project.projectName == "Kitchen Reno")
        #expect(project.roomType == .kitchen)
        #expect(project.squareFootage == 200)
        #expect(project.status == .draft)
    }

    @Test("Room type average cost ranges")
    func testRoomTypeAverageCost() {
        #expect(RoomType.kitchen.averageCostPerSqFt.lowerBound == 150)
        #expect(RoomType.kitchen.averageCostPerSqFt.upperBound == 450)
        #expect(RoomType.bathroom.averageCostPerSqFt.lowerBound == 125)
    }

    @Test("Quality tier multipliers")
    func testQualityTierMultiplier() {
        #expect(QualityTier.economy.multiplier == 0.7)
        #expect(QualityTier.standard.multiplier == 1.0)
        #expect(QualityTier.premium.multiplier == 1.5)
        #expect(QualityTier.luxury.multiplier == 2.5)
    }

    @Test("Project urgency multipliers")
    func testProjectUrgencyMultiplier() {
        #expect(ProjectUrgency.flexible.multiplier == 0.95)
        #expect(ProjectUrgency.standard.multiplier == 1.0)
        #expect(ProjectUrgency.rush.multiplier == 1.25)
        #expect(ProjectUrgency.emergency.multiplier == 1.5)
    }
}

// MARK: - Estimate Result Tests

@Suite("Estimate Result Tests")
struct EstimateResultTests {

    @Test("Estimate initialization")
    func testEstimateInitialization() {
        let estimate = EstimateResult(
            totalCostLow: 25000,
            totalCostHigh: 35000,
            confidenceScore: 0.85
        )

        #expect(estimate.totalCostLow == 25000)
        #expect(estimate.totalCostHigh == 35000)
        #expect(estimate.confidenceScore == 0.85)
    }

    @Test("Formatted total range contains currency values")
    func testFormattedTotalRange() {
        let estimate = EstimateResult(
            totalCostLow: 25000,
            totalCostHigh: 35000
        )

        #expect(estimate.formattedTotalRange.contains("25,000"))
        #expect(estimate.formattedTotalRange.contains("35,000"))
    }

    @Test("Average total cost calculation")
    func testAverageTotalCost() {
        let estimate = EstimateResult(
            totalCostLow: 20000,
            totalCostHigh: 40000
        )

        #expect(estimate.averageTotalCost == 30000)
    }

    @Test("Formatted timeline with range")
    func testFormattedTimeline() {
        let estimate = EstimateResult(
            estimatedDaysLow: 14,
            estimatedDaysHigh: 21
        )

        #expect(estimate.formattedTimeline == "14 - 21 days")
    }

    @Test("Cost breakdown categories")
    func testCostBreakdown() {
        let estimate = EstimateResult(
            laborCost: 10000,
            materialsCost: 8000,
            permitsCost: 500,
            contingencyCost: 1000
        )

        let breakdown = estimate.costBreakdown
        #expect(breakdown.count == 4)
        #expect(breakdown.contains { $0.category == "Labor" && $0.amount == 10000 })
    }
}

// MARK: - Line Item Tests

@Suite("Estimate Line Item Tests")
struct EstimateLineItemTests {

    @Test("Line item total cost calculation")
    func testLineItemTotalCost() {
        let item = EstimateLineItem(
            quantity: 10,
            unitCostLow: 50,
            unitCostHigh: 75
        )

        #expect(item.totalCostLow == 500)
        #expect(item.totalCostHigh == 750)
    }

    @Test("Formatted cost range")
    func testFormattedCostRange() {
        let item = EstimateLineItem(
            quantity: 1,
            unitCostLow: 1000,
            unitCostHigh: 1500
        )

        #expect(item.formattedCostRange.contains("1,000"))
        #expect(item.formattedCostRange.contains("1,500"))
    }
}

// MARK: - Materials Catalog Tests

@Suite("Materials Catalog Tests")
struct MaterialsCatalogTests {

    @Test("All materials catalog is not empty")
    func testAllMaterialsNotEmpty() {
        #expect(!MaterialsCatalog.allMaterials.isEmpty)
    }

    @Test("Kitchen materials exist with correct categories")
    func testKitchenMaterialsExist() {
        #expect(!MaterialsCatalog.kitchenMaterials.isEmpty)
        #expect(MaterialsCatalog.kitchenMaterials.contains { $0.category == "Countertops" })
    }

    @Test("Materials filtered by room type")
    func testMaterialsForRoomType() {
        let kitchenMaterials = MaterialsCatalog.materials(for: .kitchen)
        #expect(!kitchenMaterials.isEmpty)

        let bathroomMaterials = MaterialsCatalog.materials(for: .bathroom)
        #expect(!bathroomMaterials.isEmpty)
    }

    @Test("Material search returns matching results")
    func testMaterialSearch() {
        let results = MaterialsCatalog.search("granite")
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.name.lowercased().contains("granite") })
    }

    @Test("Empty search returns all materials")
    func testMaterialSearchEmptyQuery() {
        let results = MaterialsCatalog.search("")
        #expect(results.count == MaterialsCatalog.allMaterials.count)
    }
}

// MARK: - Network Error Tests

@Suite("Network Error Tests")
struct NetworkErrorTests {

    @Test("Error descriptions are correct")
    func testErrorDescriptions() {
        #expect(NetworkError.invalidURL.errorDescription == "Invalid URL provided")
        #expect(NetworkError.noData.errorDescription == "No data received from server")
        #expect(NetworkError.timeout.errorDescription == "Request timed out")
        #expect(NetworkError.unauthorized.errorDescription == "Authentication required")
    }

    @Test("Retryable errors are correctly identified")
    func testRetryableErrors() {
        #expect(NetworkError.timeout.isRetryable)
        #expect(NetworkError.networkUnavailable.isRetryable)
        #expect(NetworkError.rateLimited(retryAfter: nil).isRetryable)
        #expect(!NetworkError.invalidURL.isRetryable)
        #expect(!NetworkError.unauthorized.isRetryable)
    }
}

// MARK: - Gemini Response Parsing Tests

@Suite("Gemini Response Parsing Tests")
struct GeminiResponseParsingTests {

    @Test("Parse estimate response from JSON")
    func testParseEstimateResponse() throws {
        let json = """
        {
            "totalCost": {"low": 25000, "high": 35000},
            "breakdown": [
                {
                    "category": "Labor",
                    "item": "General Labor",
                    "description": "Skilled labor",
                    "quantity": 100,
                    "unit": "hours",
                    "costLow": 5000,
                    "costHigh": 7000,
                    "optional": false
                }
            ],
            "timeline": {
                "daysLow": 14,
                "daysHigh": 21,
                "recommendedSeason": "Spring"
            },
            "notes": "Test notes",
            "confidence": 0.85
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(GeminiEstimateResponse.self, from: data)

        #expect(response.totalCost.low == 25000)
        #expect(response.totalCost.high == 35000)
        #expect(response.breakdown.count == 1)
        #expect(response.timeline.daysLow == 14)
        #expect(response.confidence == 0.85)
    }

    @Test("Convert API response to EstimateResult")
    func testConvertToEstimateResult() {
        let response = GeminiEstimateResponse(
            totalCost: GeminiEstimateResponse.CostRange(low: 20000, high: 30000),
            breakdown: [
                GeminiEstimateResponse.BreakdownItem(
                    category: "Labor",
                    item: "Installation",
                    description: "Professional installation",
                    quantity: 1,
                    unit: "lot",
                    costLow: 5000,
                    costHigh: 7000,
                    optional: false
                )
            ],
            timeline: GeminiEstimateResponse.TimelineInfo(
                daysLow: 7,
                daysHigh: 14,
                recommendedSeason: "Summer"
            ),
            notes: "Test estimate",
            warnings: ["Warning 1"],
            recommendations: ["Recommendation 1"],
            confidence: 0.9,
            regionalData: GeminiEstimateResponse.RegionalData(multiplier: 1.1, region: "California")
        )

        let result = response.toEstimateResult()

        #expect(result.totalCostLow == 20000)
        #expect(result.totalCostHigh == 30000)
        #expect(result.estimatedDaysLow == 7)
        #expect(result.estimatedDaysHigh == 14)
        #expect(result.confidenceScore == 0.9)
        #expect(result.regionMultiplier == 1.1)
        #expect(result.regionName == "California")
        #expect(result.warnings.count == 1)
        #expect(result.recommendations.count == 1)
    }
}

// MARK: - Image Style Tests

@Suite("Image Style Tests")
struct ImageStyleTests {

    @Test("Prompt modifiers contain style keywords")
    func testPromptModifiers() {
        #expect(ImageStyle.photorealistic.promptModifier.contains("photorealistic"))
        #expect(ImageStyle.modern.promptModifier.contains("modern"))
        #expect(ImageStyle.architectural.promptModifier.contains("architectural"))
    }
}

// MARK: - User Tests

@Suite("User Tests")
struct UserTests {

    @Test("Can generate estimate based on subscription")
    func testCanGenerateEstimate() {
        let user = User(subscriptionTier: .professional)
        user.estimatesGeneratedThisMonth = 50

        #expect(user.canGenerateEstimate)

        user.estimatesGeneratedThisMonth = 100
        #expect(!user.canGenerateEstimate)
    }

    @Test("Remaining estimates calculation")
    func testRemainingEstimates() {
        let user = User(subscriptionTier: .professional)
        user.estimatesGeneratedThisMonth = 30

        #expect(user.remainingEstimates == 70)
    }

    @Test("Formatted display name priority")
    func testFormattedDisplayName() {
        let user = User(email: "test@example.com", displayName: "John Doe", companyName: "ABC Contractors")

        #expect(user.formattedDisplayName == "ABC Contractors")

        user.companyName = ""
        #expect(user.formattedDisplayName == "John Doe")

        user.displayName = ""
        #expect(user.formattedDisplayName == "test@example.com")
    }
}

// MARK: - Subscription Tier Tests

@Suite("Subscription Tier Tests")
struct SubscriptionTierTests {

    @Test("Estimate limits per tier")
    func testEstimateLimits() {
        #expect(SubscriptionTier.free.estimateLimit == 5)
        #expect(SubscriptionTier.professional.estimateLimit == 100)
        #expect(SubscriptionTier.enterprise.estimateLimit == Int.max)
    }

    @Test("Image limits per tier")
    func testImageLimits() {
        #expect(SubscriptionTier.free.imageLimit == 3)
        #expect(SubscriptionTier.professional.imageLimit == 50)
        #expect(SubscriptionTier.enterprise.imageLimit == Int.max)
    }

    @Test("Pricing per tier")
    func testPricing() {
        #expect(SubscriptionTier.free.monthlyPrice == 0)
        #expect(SubscriptionTier.professional.monthlyPrice == 49.99)
        #expect(SubscriptionTier.enterprise.monthlyPrice == 199.99)
    }
}

// MARK: - Project Form State Tests

@Suite("Project Form State Tests")
struct ProjectFormStateTests {

    @Test("Form validation")
    func testIsValid() {
        var formState = ProjectFormState()

        #expect(!formState.isValid)

        formState.squareFootage = "200"
        #expect(formState.isValid)

        formState.squareFootage = "0"
        #expect(!formState.isValid)

        formState.squareFootage = "150000"
        #expect(!formState.isValid)
    }

    @Test("Square footage value parsing")
    func testSquareFootageValue() {
        var formState = ProjectFormState()
        formState.squareFootage = "250.5"

        #expect(formState.squareFootageValue == 250.5)
    }

    @Test("Convert form state to project")
    func testToProject() {
        var formState = ProjectFormState()
        formState.projectName = "Test Project"
        formState.roomType = .bathroom
        formState.squareFootage = "150"
        formState.qualityTier = .premium

        let project = formState.toProject()

        #expect(project.projectName == "Test Project")
        #expect(project.roomType == .bathroom)
        #expect(project.squareFootage == 150)
        #expect(project.qualityTier == .premium)
    }

    @Test("Form reset clears all fields")
    func testReset() {
        var formState = ProjectFormState()
        formState.projectName = "Test"
        formState.squareFootage = "200"

        formState.reset()

        #expect(formState.projectName == "")
        #expect(formState.squareFootage == "")
    }
}
