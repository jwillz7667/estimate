//
//  ProjectViewModel.swift
//  ProjectEstimate
//
//  ViewModel for project creation and estimate generation
//  Handles all business logic for renovation project workflow
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import OSLog

// MARK: - Project Form State

/// Form state for project input
struct ProjectFormState: Sendable {
    var projectName: String = ""
    var roomType: RoomType = .kitchen
    var squareFootage: String = ""
    var location: String = ""
    var zipCode: String = ""
    var budgetMin: String = ""
    var budgetMax: String = ""
    var selectedMaterials: Set<String> = []
    var qualityTier: QualityTier = .standard
    var notes: String = ""
    var urgency: ProjectUrgency = .standard
    var includesPermits: Bool = true
    var includesDesign: Bool = false

    // Image upload data
    var uploadedImages: [Data] = []
    var renovationDescription: String = ""

    var squareFootageValue: Double {
        Double(squareFootage) ?? 0
    }

    var budgetMinValue: Double {
        Double(budgetMin) ?? 0
    }

    var budgetMaxValue: Double {
        Double(budgetMax) ?? 0
    }

    var isValid: Bool {
        squareFootageValue > 0 && squareFootageValue < 100000
    }

    mutating func reset() {
        self = ProjectFormState()
    }

    func toProject() -> RenovationProject {
        RenovationProject(
            projectName: projectName,
            roomType: roomType,
            squareFootage: squareFootageValue,
            location: location,
            zipCode: zipCode,
            budgetMin: budgetMinValue,
            budgetMax: budgetMaxValue,
            selectedMaterials: Array(selectedMaterials),
            qualityTier: qualityTier,
            notes: notes,
            urgency: urgency,
            includesPermits: includesPermits,
            includesDesign: includesDesign,
            uploadedImageData: uploadedImages,
            renovationDescription: renovationDescription
        )
    }

    var hasUploadedImages: Bool {
        !uploadedImages.isEmpty
    }
}

// MARK: - Project ViewModel

@MainActor
@Observable
final class ProjectViewModel {

    // MARK: - Published State

    var formState = ProjectFormState()
    var currentProject: RenovationProject?
    var currentEstimate: EstimateResult?
    var generatedImages: [GeneratedImage] = []

    // MARK: - Loading States

    var isGeneratingEstimate = false
    var isGeneratingImage = false
    var isSaving = false

    // MARK: - Progress

    var estimateProgress: Double = 0
    var estimateStatusMessage: String = ""

    // MARK: - Error State

    var error: Error?
    var showError = false

    // MARK: - Subscription State

    var showPaywall = false
    var usageLimitReached = false
    var limitReachedFeature: PremiumFeature?

    // MARK: - Image Generation State

    var selectedImageStyle: ImageStyle = .photorealistic
    var selectedAspectRatio: ImageAspectRatio = .landscape
    var imagePrompt: String = ""

    // MARK: - Materials Search

    var materialsSearchQuery: String = ""
    var filteredMaterials: [MaterialItem] = []

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let geminiService: GeminiAPIService
    private let localSellersService = LocalSellersService()
    private let pricingService = PricingSearchService()
    private let logger = Logger(subsystem: "com.projectestimate", category: "ProjectViewModel")

    // MARK: - Pricing Search Results

    var materialPrices: [PricingSearchResult] = []
    var laborRates: [LaborRateResult] = []
    var isLoadingPrices = false

    // MARK: - Local Pricing State

    var localSellers: [LocalSeller] = []
    var materialQuotes: [MaterialQuote] = []
    var regionalPricing: RegionalPriceData?
    var isLoadingLocalPricing = false

    // MARK: - Initialization

    init(modelContext: ModelContext, geminiService: GeminiAPIService) {
        self.modelContext = modelContext
        self.geminiService = geminiService
        self.filteredMaterials = MaterialsCatalog.materials(for: .kitchen)
    }

    // MARK: - Form Actions

    func updateRoomType(_ type: RoomType) {
        formState.roomType = type
        filteredMaterials = MaterialsCatalog.materials(for: type)
        updateDefaultBudget()
    }

    func toggleMaterial(_ material: String) {
        if formState.selectedMaterials.contains(material) {
            formState.selectedMaterials.remove(material)
        } else {
            formState.selectedMaterials.insert(material)
        }
    }

    func searchMaterials(_ query: String) {
        materialsSearchQuery = query
        if query.isEmpty {
            filteredMaterials = MaterialsCatalog.materials(for: formState.roomType)
        } else {
            filteredMaterials = MaterialsCatalog.search(query)
        }
    }

    private func updateDefaultBudget() {
        let sqft = formState.squareFootageValue
        guard sqft > 0 else { return }

        let range = formState.roomType.averageCostPerSqFt
        let multiplier = formState.qualityTier.multiplier

        let minCost = sqft * range.lowerBound * multiplier
        let maxCost = sqft * range.upperBound * multiplier

        formState.budgetMin = String(Int(minCost))
        formState.budgetMax = String(Int(maxCost))
    }

    func updateBudgetFromSquareFootage() {
        updateDefaultBudget()
    }

    // MARK: - Local Pricing

    /// Fetches local seller and pricing data based on ZIP code
    func fetchLocalPricing() async {
        guard !formState.zipCode.isEmpty else { return }

        isLoadingLocalPricing = true
        defer { isLoadingLocalPricing = false }

        do {
            // Fetch local sellers
            localSellers = try await localSellersService.getLocalSellers(
                zipCode: formState.zipCode,
                projectType: formState.roomType
            )

            // Fetch regional pricing data
            regionalPricing = await localSellersService.getRegionalPricing(zipCode: formState.zipCode)

            // If materials are selected, get quotes
            if !formState.selectedMaterials.isEmpty {
                materialQuotes = try await localSellersService.getMaterialQuotes(
                    materials: Array(formState.selectedMaterials),
                    zipCode: formState.zipCode
                )
            }

            logger.info("Loaded \(self.localSellers.count) local sellers and \(self.materialQuotes.count) quotes")
        } catch {
            logger.error("Failed to fetch local pricing: \(error.localizedDescription)")
        }
    }

    // MARK: - Real-Time Pricing Search

    /// Fetches current market prices for selected materials and labor
    func fetchRealTimePricing() async {
        guard !formState.zipCode.isEmpty else { return }

        isLoadingPrices = true
        defer { isLoadingPrices = false }

        // Fetch material prices
        if !formState.selectedMaterials.isEmpty {
            materialPrices = await pricingService.searchMaterialPrices(
                materials: Array(formState.selectedMaterials),
                zipCode: formState.zipCode
            )
        }

        // Fetch labor rates for the project type
        laborRates = await pricingService.getLaborRatesForProject(
            roomType: formState.roomType,
            zipCode: formState.zipCode
        )

        logger.info("Fetched \(self.materialPrices.count) material prices and \(self.laborRates.count) labor rates")
    }

    /// Gets a specific material price
    func getMaterialPrice(for material: String) async -> PricingSearchResult {
        return await pricingService.searchMaterialPrice(
            material: material,
            zipCode: formState.zipCode
        )
    }

    /// Gets a specific labor rate
    func getLaborRate(for trade: String) async -> LaborRateResult {
        return await pricingService.searchLaborRate(
            trade: trade,
            zipCode: formState.zipCode
        )
    }

    // MARK: - Project Actions

    func createProject() -> RenovationProject {
        let project = formState.toProject()
        modelContext.insert(project)
        currentProject = project
        logger.info("Created project: \(project.projectName)")
        return project
    }

    func saveProject() async throws {
        isSaving = true
        defer { isSaving = false }

        try modelContext.save()
        logger.info("Project saved successfully")
    }

    // MARK: - Estimate Generation

    func generateEstimate() async {
        guard formState.isValid else {
            error = NSError(domain: "ProjectViewModel", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Please enter valid square footage"
            ])
            showError = true
            return
        }

        isGeneratingEstimate = true
        estimateProgress = 0
        estimateStatusMessage = "Preparing request..."

        do {
            // Create or update project
            let project: RenovationProject
            if let existing = currentProject {
                existing.squareFootage = formState.squareFootageValue
                existing.roomType = formState.roomType
                existing.qualityTier = formState.qualityTier
                existing.selectedMaterials = Array(formState.selectedMaterials)
                existing.location = formState.location
                existing.zipCode = formState.zipCode
                existing.notes = formState.notes
                existing.urgency = formState.urgency
                existing.includesPermits = formState.includesPermits
                existing.includesDesign = formState.includesDesign
                existing.status = .estimating
                project = existing
            } else {
                project = createProject()
                project.status = .estimating
            }

            estimateProgress = 0.1
            estimateStatusMessage = "Fetching local pricing data..."

            // Fetch local pricing if ZIP code is provided
            if !formState.zipCode.isEmpty {
                await fetchLocalPricing()
                await fetchRealTimePricing()
            }

            estimateProgress = 0.2
            estimateStatusMessage = "Analyzing project requirements..."

            // Call Gemini API - use vision if images are available
            let response: GeminiEstimateResponse
            if !formState.uploadedImages.isEmpty {
                estimateStatusMessage = "Analyzing your photos with AI vision..."
                response = try await geminiService.generateEstimateWithImages(for: project, images: formState.uploadedImages)
            } else {
                response = try await geminiService.generateEstimate(for: project)
            }

            estimateProgress = 0.7
            estimateStatusMessage = "Processing estimate..."

            // Convert response to model
            let estimate = response.toEstimateResult()
            estimate.project = project
            estimate.rawAPIResponse = try? String(data: JSONEncoder().encode(response), encoding: .utf8)

            modelContext.insert(estimate)

            // Update project
            project.status = .estimated
            project.updatedAt = Date()

            currentEstimate = estimate
            currentProject = project

            estimateProgress = 1.0
            estimateStatusMessage = "Estimate complete!"

            try modelContext.save()

            logger.info("Estimate generated: \(estimate.formattedTotalRange)")

            // Auto-generate image prompt
            generateImagePromptFromProject()

        } catch {
            self.error = error
            self.showError = true
            logger.error("Estimate generation failed: \(error.localizedDescription)")
        }

        isGeneratingEstimate = false
    }

    // MARK: - AI Visualization Generation

    /// Generates a visualization of the completed renovation based on uploaded photos
    func generateVisualization() async {
        guard !formState.uploadedImages.isEmpty else {
            error = NSError(domain: "ProjectViewModel", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Please upload photos of your space first"
            ])
            showError = true
            return
        }

        guard !formState.renovationDescription.isEmpty else {
            error = NSError(domain: "ProjectViewModel", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Please describe your desired renovation"
            ])
            showError = true
            return
        }

        isGeneratingImage = true

        do {
            let imageData = try await geminiService.generateVisualization(
                currentImages: formState.uploadedImages,
                description: formState.renovationDescription,
                style: selectedImageStyle
            )

            let generatedImage = GeneratedImage(
                imageData: imageData,
                prompt: "Visualization: \(formState.renovationDescription)",
                style: selectedImageStyle,
                aspectRatio: .landscape,
                title: "Renovation Preview for \(currentProject?.projectName ?? "Project")"
            )

            generatedImage.generateThumbnail()
            generatedImage.project = currentProject

            modelContext.insert(generatedImage)
            generatedImages.append(generatedImage)

            try modelContext.save()

            logger.info("Visualization generated successfully")

        } catch {
            self.error = error
            self.showError = true
            logger.error("Visualization generation failed: \(error.localizedDescription)")
        }

        isGeneratingImage = false
    }

    // MARK: - Image Generation

    func generateImagePromptFromProject() {
        guard let project = currentProject else { return }

        let materials = project.selectedMaterials.isEmpty
            ? "modern materials"
            : project.selectedMaterials.prefix(3).joined(separator: ", ")

        imagePrompt = """
        A beautifully renovated \(project.roomType.rawValue.lowercased()) \
        with \(project.qualityTier.rawValue.lowercased()) quality finishes, \
        featuring \(materials), \
        spacious \(Int(project.squareFootage)) square foot layout
        """
    }

    func generateImage() async {
        guard !imagePrompt.isEmpty else {
            error = NSError(domain: "ProjectViewModel", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Please enter an image prompt"
            ])
            showError = true
            return
        }

        isGeneratingImage = true

        do {
            let imageData = try await geminiService.generateImage(
                prompt: imagePrompt,
                style: selectedImageStyle,
                aspectRatio: selectedAspectRatio
            )

            let generatedImage = GeneratedImage(
                imageData: imageData,
                prompt: imagePrompt,
                style: selectedImageStyle,
                aspectRatio: selectedAspectRatio,
                title: "Visualization for \(currentProject?.projectName ?? "Project")"
            )

            generatedImage.generateThumbnail()
            generatedImage.project = currentProject

            modelContext.insert(generatedImage)
            generatedImages.append(generatedImage)

            try modelContext.save()

            logger.info("Image generated successfully")

        } catch {
            self.error = error
            self.showError = true
            logger.error("Image generation failed: \(error.localizedDescription)")
        }

        isGeneratingImage = false
    }

    // MARK: - Reset

    func resetForm() {
        formState.reset()
        currentProject = nil
        currentEstimate = nil
        generatedImages = []
        error = nil
        showError = false
    }

    // MARK: - Validation

    var canGenerateEstimate: Bool {
        formState.isValid && !isGeneratingEstimate
    }

    var canGenerateImage: Bool {
        !imagePrompt.isEmpty && !isGeneratingImage && currentEstimate != nil
    }

    // MARK: - Subscription Checks

    /// Checks if user can generate an estimate based on subscription
    func checkEstimateEntitlement(subscriptionService: SubscriptionService) -> Bool {
        let status = subscriptionService.subscriptionStatus

        // Free tier has limited estimates
        if status.tier == .free {
            let usedEstimates = subscriptionService.getMonthlyUsage(.unlimitedEstimates)
            if usedEstimates >= status.tier.estimateLimit {
                usageLimitReached = true
                limitReachedFeature = .unlimitedEstimates
                return false
            }
        }

        return true
    }

    /// Checks if user can generate an image based on subscription
    func checkImageEntitlement(subscriptionService: SubscriptionService) -> Bool {
        let status = subscriptionService.subscriptionStatus

        // Check if image generation is available
        if !subscriptionService.canAccessFeature(.imageGeneration) {
            showPaywall = true
            return false
        }

        // Check usage limits
        let usedImages = subscriptionService.getMonthlyUsage(.imageGeneration)
        if usedImages >= status.tier.imageLimit && status.tier.imageLimit != Int.max {
            usageLimitReached = true
            limitReachedFeature = .imageGeneration
            return false
        }

        return true
    }

    /// Tracks estimate generation usage
    func trackEstimateUsage(subscriptionService: SubscriptionService) {
        subscriptionService.trackFeatureUsage(.unlimitedEstimates)
    }

    /// Tracks image generation usage
    func trackImageUsage(subscriptionService: SubscriptionService) {
        subscriptionService.trackFeatureUsage(.imageGeneration)
    }

    /// Generates estimate with subscription check
    func generateEstimateWithSubscriptionCheck(subscriptionService: SubscriptionService) async {
        guard checkEstimateEntitlement(subscriptionService: subscriptionService) else {
            return
        }

        await generateEstimate()

        // Track usage on success
        if currentEstimate != nil {
            trackEstimateUsage(subscriptionService: subscriptionService)
        }
    }

    /// Generates image with subscription check
    func generateImageWithSubscriptionCheck(subscriptionService: SubscriptionService) async {
        guard checkImageEntitlement(subscriptionService: subscriptionService) else {
            return
        }

        await generateImage()

        // Track usage on success
        if !generatedImages.isEmpty {
            trackImageUsage(subscriptionService: subscriptionService)
        }
    }

    /// Generates visualization with subscription check
    func generateVisualizationWithSubscriptionCheck(subscriptionService: SubscriptionService) async {
        guard checkImageEntitlement(subscriptionService: subscriptionService) else {
            return
        }

        await generateVisualization()

        // Track usage on success
        if !generatedImages.isEmpty {
            trackImageUsage(subscriptionService: subscriptionService)
        }
    }
}

// MARK: - Preview Helper

extension ProjectViewModel {
    static func preview(modelContext: ModelContext) -> ProjectViewModel {
        let vm = ProjectViewModel(
            modelContext: modelContext,
            geminiService: GeminiAPIService()
        )
        vm.formState.projectName = "Kitchen Renovation"
        vm.formState.roomType = .kitchen
        vm.formState.squareFootage = "200"
        vm.formState.qualityTier = .premium
        return vm
    }
}
