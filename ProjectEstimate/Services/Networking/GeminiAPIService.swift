//
//  GeminiAPIService.swift
//  ProjectEstimate
//
//  Gemini AI API integration for renovation cost estimates
//  Supports Gemini 2.5 Flash for text and Nano Banana Pro for image generation
//

import Foundation
import OSLog
import UIKit

// MARK: - Gemini API Configuration

/// Configuration for Gemini API endpoints and models
enum GeminiAPIConfiguration {
    // Text generation model - Using Gemini 3.0 Pro for best estimate quality
    static let textModel = "gemini-3.0-pro"

    // Fallback model if primary is not available
    static let fallbackTextModel = "gemini-2.0-flash"

    // Image generation model - Nano Banana Pro (Gemini 3 Pro Image)
    static let imageModel = "gemini-3-pro-image-preview"

    // API Endpoints
    static let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    static let generateContentEndpoint = "/models/\(textModel):generateContent"
    static let generateImageEndpoint = "/models/\(imageModel):generateContent"

    // Generation settings - optimized for quality
    static let maxOutputTokens = 4096
    static let temperature: Double = 0.3  // Lower for consistent estimates
    static let topP: Double = 0.9
    static let topK: Int = 32

    // Timeout settings
    static let estimateTimeout: TimeInterval = 60
    static let imageTimeout: TimeInterval = 90
    static let validationTimeout: TimeInterval = 15
}

// MARK: - Request/Response DTOs

/// Gemini API request body
struct GeminiRequest: Codable {
    let contents: [Content]
    let generationConfig: GenerationConfig?
    let safetySettings: [SafetySetting]?

    struct Content: Codable {
        let parts: [Part]
        let role: String?
    }

    struct Part: Codable {
        let text: String?
        let inlineData: InlineData?

        init(text: String? = nil, inlineData: InlineData? = nil) {
            self.text = text
            self.inlineData = inlineData
        }
    }

    struct InlineData: Codable {
        let mimeType: String
        let data: String
    }

    struct GenerationConfig: Codable {
        let temperature: Double?
        let topP: Double?
        let topK: Int?
        let maxOutputTokens: Int?
        let responseMimeType: String?
    }

    struct SafetySetting: Codable {
        let category: String
        let threshold: String
    }
}

/// Gemini API response
struct GeminiResponse: Codable {
    let candidates: [Candidate]?
    let usageMetadata: UsageMetadata?
    let error: GeminiError?

    struct Candidate: Codable {
        let content: Content?
        let finishReason: String?
        let safetyRatings: [SafetyRating]?
    }

    struct Content: Codable {
        let parts: [Part]?
        let role: String?
    }

    struct Part: Codable {
        let text: String?
    }

    struct SafetyRating: Codable {
        let category: String
        let probability: String
    }

    struct UsageMetadata: Codable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
        let totalTokenCount: Int?
    }

    struct GeminiError: Codable {
        let code: Int
        let message: String
        let status: String
    }
}

/// Gemini Image Generation Request (uses generateContent with image output)
struct GeminiImageRequest: Codable {
    let contents: [Content]
    let generationConfig: GenerationConfig?

    struct Content: Codable {
        let parts: [Part]
        let role: String?
    }

    struct Part: Codable {
        let text: String?
    }

    struct GenerationConfig: Codable {
        let responseModalities: [String]?
        let responseMimeType: String?

        enum CodingKeys: String, CodingKey {
            case responseModalities = "response_modalities"
            case responseMimeType = "responseMimeType"
        }
    }
}

/// Gemini Image Generation Response
struct GeminiImageResponse: Codable {
    let candidates: [Candidate]?
    let error: GeminiError?

    struct Candidate: Codable {
        let content: Content?
    }

    struct Content: Codable {
        let parts: [Part]?
    }

    struct Part: Codable {
        let text: String?
        let inlineData: InlineData?

        struct InlineData: Codable {
            let mimeType: String
            let data: String
        }
    }

    struct GeminiError: Codable {
        let code: Int
        let message: String
        let status: String
    }
}

// MARK: - Gemini API Service Protocol

protocol GeminiAPIServiceProtocol {
    func generateEstimate(for project: RenovationProject) async throws -> GeminiEstimateResponse
    func generateEstimateWithImages(for project: RenovationProject, images: [Data]) async throws -> GeminiEstimateResponse
    func generateVisualization(currentImages: [Data], description: String, style: ImageStyle) async throws -> Data
    func generateImage(prompt: String, style: ImageStyle, aspectRatio: ImageAspectRatio) async throws -> Data
    func validateAPIKey() async throws -> Bool
}

// MARK: - Gemini API Service Implementation

/// Production-ready Gemini API service with comprehensive error handling
final class GeminiAPIService: GeminiAPIServiceProtocol {

    // MARK: - Properties

    private let session: URLSession
    private let keyManager: APIKeyManager
    private let logger: Logger

    // MARK: - Initialization

    init(
        session: URLSession = .shared,
        keyManager: APIKeyManager = APIKeyManager()
    ) {
        self.session = session
        self.keyManager = keyManager
        self.logger = Logger(subsystem: "com.projectestimate", category: "GeminiAPI")
    }

    // MARK: - Estimate Generation

    /// Generates detailed renovation estimate using Gemini 2.0 Flash (optimized for speed)
    func generateEstimate(for project: RenovationProject) async throws -> GeminiEstimateResponse {
        let apiKey = try await keyManager.getGeminiAPIKey()

        // Build the optimized prompt
        let prompt = buildEstimatePrompt(for: project)

        // Create request body with optimized settings
        let requestBody = GeminiRequest(
            contents: [
                GeminiRequest.Content(
                    parts: [GeminiRequest.Part(text: prompt)],
                    role: "user"
                )
            ],
            generationConfig: GeminiRequest.GenerationConfig(
                temperature: GeminiAPIConfiguration.temperature,
                topP: GeminiAPIConfiguration.topP,
                topK: GeminiAPIConfiguration.topK,
                maxOutputTokens: GeminiAPIConfiguration.maxOutputTokens,
                responseMimeType: "application/json"
            ),
            safetySettings: [
                GeminiRequest.SafetySetting(category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_ONLY_HIGH"),
                GeminiRequest.SafetySetting(category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_ONLY_HIGH"),
                GeminiRequest.SafetySetting(category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_ONLY_HIGH"),
                GeminiRequest.SafetySetting(category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_ONLY_HIGH")
            ]
        )

        // Build URL with primary model
        guard let url = URL(string: "\(GeminiAPIConfiguration.baseURL)/models/\(GeminiAPIConfiguration.textModel):generateContent?key=\(apiKey)") else {
            throw NetworkError.invalidURL
        }

        // Create URLRequest with optimized timeout
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        urlRequest.timeoutInterval = GeminiAPIConfiguration.estimateTimeout

        logger.info("Sending estimate request to Gemini 3.0 Pro")

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(URLError(.badServerResponse))
            }

            guard httpResponse.statusCode == 200 else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("API error: \(httpResponse.statusCode) - \(message)")

                // If primary model fails, try fallback
                if httpResponse.statusCode == 404 || httpResponse.statusCode == 400 {
                    logger.info("Trying fallback model...")
                    return try await generateEstimateWithFallback(for: project, apiKey: apiKey, requestBody: requestBody)
                }

                throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: message)
            }

            return try parseEstimateResponse(from: data)

        } catch let error as URLError where error.code == .timedOut {
            logger.warning("Request timed out, trying fallback model...")
            return try await generateEstimateWithFallback(for: project, apiKey: apiKey, requestBody: requestBody)
        }
    }

    /// Fallback estimate generation using alternative model
    private func generateEstimateWithFallback(for project: RenovationProject, apiKey: String, requestBody: GeminiRequest) async throws -> GeminiEstimateResponse {
        guard let url = URL(string: "\(GeminiAPIConfiguration.baseURL)/models/\(GeminiAPIConfiguration.fallbackTextModel):generateContent?key=\(apiKey)") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        urlRequest.timeoutInterval = GeminiAPIConfiguration.estimateTimeout

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NetworkError.serverError("Fallback model also failed: \(message)")
        }

        return try parseEstimateResponse(from: data)
    }

    /// Parse estimate response from API data
    private func parseEstimateResponse(from data: Data) throws -> GeminiEstimateResponse {
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        // Check for API error
        if let error = geminiResponse.error {
            logger.error("Gemini API error: \(error.message)")
            throw NetworkError.serverError(error.message)
        }

        // Extract text response
        guard let candidate = geminiResponse.candidates?.first,
              let text = candidate.content?.parts?.first?.text else {
            throw NetworkError.noData
        }

        logger.debug("Received estimate response")

        // Clean the JSON response (remove markdown code blocks if present)
        let cleanedText = cleanJSONResponse(text)

        // Parse JSON response
        guard let jsonData = cleanedText.data(using: String.Encoding.utf8) else {
            throw NetworkError.decodingError(NSError(domain: "GeminiAPI", code: -1))
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            return try decoder.decode(GeminiEstimateResponse.self, from: jsonData)
        } catch {
            logger.error("Failed to decode estimate response: \(error)")
            // Try to parse as loose JSON
            return try parseLooseEstimateResponse(from: cleanedText)
        }
    }

    /// Clean JSON response by removing markdown code blocks
    private func cleanJSONResponse(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove ```json and ``` markers
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }

        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Vision-Based Estimate Generation

    /// Generates estimate by analyzing user-uploaded images of the renovation area
    /// Memory-optimized: processes images one at a time and aggressively compresses
    func generateEstimateWithImages(for project: RenovationProject, images: [Data]) async throws -> GeminiEstimateResponse {
        let apiKey = try await keyManager.getGeminiAPIKey()

        // Build vision prompt with image analysis
        let prompt = buildVisionEstimatePrompt(for: project)

        // Create parts array with text and images
        // MEMORY OPTIMIZATION: Limit to 2 images and compress aggressively
        var parts: [GeminiRequest.Part] = [GeminiRequest.Part(text: prompt)]

        // Process images with memory-efficient compression (max 2 images, 512KB each)
        let processedImages = await processImagesForAPI(images: Array(images.prefix(2)), maxSizeKB: 512)

        for imageBase64 in processedImages {
            let inlineData = GeminiRequest.InlineData(mimeType: "image/jpeg", data: imageBase64)
            parts.append(GeminiRequest.Part(text: nil, inlineData: inlineData))
        }

        let requestBody = GeminiRequest(
            contents: [
                GeminiRequest.Content(parts: parts, role: "user")
            ],
            generationConfig: GeminiRequest.GenerationConfig(
                temperature: 0.3,  // Lower temperature for more accurate estimates
                topP: GeminiAPIConfiguration.topP,
                topK: GeminiAPIConfiguration.topK,
                maxOutputTokens: GeminiAPIConfiguration.maxOutputTokens,
                responseMimeType: "application/json"
            ),
            safetySettings: [
                GeminiRequest.SafetySetting(category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_ONLY_HIGH"),
                GeminiRequest.SafetySetting(category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_ONLY_HIGH"),
                GeminiRequest.SafetySetting(category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_ONLY_HIGH"),
                GeminiRequest.SafetySetting(category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_ONLY_HIGH")
            ]
        )

        // Use Gemini 3.0 Pro which supports vision
        let visionEndpoint = "/models/\(GeminiAPIConfiguration.textModel):generateContent"
        guard let url = URL(string: "\(GeminiAPIConfiguration.baseURL)\(visionEndpoint)?key=\(apiKey)") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        urlRequest.timeoutInterval = GeminiAPIConfiguration.estimateTimeout

        logger.info("Sending vision-based estimate request with \(processedImages.count) images")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Vision API error: \(httpResponse.statusCode) - \(message)")

            // Fallback to text-only estimate if vision fails
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 413 {
                logger.info("Vision request too large, falling back to text-only estimate")
                return try await generateEstimate(for: project)
            }

            throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        return try parseEstimateResponse(from: data)
    }

    /// Process images for API with aggressive memory optimization
    private func processImagesForAPI(images: [Data], maxSizeKB: Int) async -> [String] {
        var result: [String] = []

        for imageData in images {
            autoreleasepool {
                let compressedData = compressImageDataAggressive(imageData, maxSizeKB: maxSizeKB)
                let base64 = compressedData.base64EncodedString()
                result.append(base64)
            }
        }

        return result
    }

    /// Aggressive image compression for memory optimization
    private func compressImageDataAggressive(_ data: Data, maxSizeKB: Int) -> Data {
        guard let image = UIImage(data: data) else { return data }

        // First, resize to max 1024px on longest side
        let maxDimension: CGFloat = 1024
        let scale = min(maxDimension / max(image.size.width, image.size.height), 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        var resizedImage: UIImage = image
        if scale < 1.0 {
            let renderer = UIGraphicsImageRenderer(size: newSize)
            resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        // Now compress with decreasing quality until under size limit
        var compression: CGFloat = 0.7
        var compressedData = resizedImage.jpegData(compressionQuality: compression) ?? data

        while compressedData.count > maxSizeKB * 1024 && compression > 0.1 {
            compression -= 0.15
            compressedData = resizedImage.jpegData(compressionQuality: compression) ?? compressedData
        }

        // If still too large, resize further
        if compressedData.count > maxSizeKB * 1024 {
            let furtherScale = sqrt(Double(maxSizeKB * 1024) / Double(compressedData.count)) * 0.9
            let finalSize = CGSize(width: newSize.width * furtherScale, height: newSize.height * furtherScale)
            let finalRenderer = UIGraphicsImageRenderer(size: finalSize)
            let finalImage = finalRenderer.image { _ in
                resizedImage.draw(in: CGRect(origin: .zero, size: finalSize))
            }
            compressedData = finalImage.jpegData(compressionQuality: 0.6) ?? compressedData
        }

        return compressedData
    }

    // MARK: - Renovation Visualization

    /// Generates a visualization of completed renovation based on current photos and description
    func generateVisualization(currentImages: [Data], description: String, style: ImageStyle) async throws -> Data {
        let apiKey = try await keyManager.getGeminiAPIKey()

        let visualizationPrompt = """
        Based on the attached photos showing the current state of this space, create a photorealistic visualization of how it will look after the following renovation:

        RENOVATION DESCRIPTION:
        \(description)

        REQUIREMENTS:
        - Show the SAME space from the SAME angle as the original photos
        - Apply the described renovations realistically
        - Maintain proper lighting and perspective
        - Use high-quality, professional interior design aesthetics
        - Style: \(style.promptModifier)
        - Make it look like a completed, professional renovation
        """

        // Create parts with text and images
        var parts: [GeminiRequest.Part] = [GeminiRequest.Part(text: visualizationPrompt)]

        // Add the current state images
        for imageData in currentImages.prefix(3) {
            let compressedData = compressImageData(imageData, maxSizeKB: 1024)
            let base64Image = compressedData.base64EncodedString()
            let inlineData = GeminiRequest.InlineData(mimeType: "image/jpeg", data: base64Image)
            parts.append(GeminiRequest.Part(text: nil, inlineData: inlineData))
        }

        let requestBody = GeminiImageRequest(
            contents: [
                GeminiImageRequest.Content(
                    parts: parts.map { GeminiImageRequest.Part(text: $0.text) },
                    role: "user"
                )
            ],
            generationConfig: GeminiImageRequest.GenerationConfig(
                responseModalities: ["TEXT", "IMAGE"],
                responseMimeType: nil
            )
        )

        guard let url = URL(string: "\(GeminiAPIConfiguration.baseURL)\(GeminiAPIConfiguration.generateImageEndpoint)?key=\(apiKey)") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        urlRequest.timeoutInterval = 120

        logger.info("Sending visualization request with \(currentImages.count) reference images")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Visualization generation error: \(httpResponse.statusCode) - \(message)")
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        let geminiResponse = try JSONDecoder().decode(GeminiImageResponse.self, from: data)

        if let error = geminiResponse.error {
            logger.error("Gemini visualization error: \(error.message)")
            throw NetworkError.serverError(error.message)
        }

        guard let candidate = geminiResponse.candidates?.first,
              let parts = candidate.content?.parts else {
            throw NetworkError.noData
        }

        for part in parts {
            if let inlineData = part.inlineData,
               let imageBytes = Data(base64Encoded: inlineData.data) {
                logger.debug("Received visualization image (\(imageBytes.count) bytes)")
                return imageBytes
            }
        }

        throw NetworkError.noData
    }

    // MARK: - Image Compression Helper

    private func compressImageData(_ data: Data, maxSizeKB: Int) -> Data {
        guard let image = UIImage(data: data) else { return data }

        var compression: CGFloat = 0.8
        var compressedData = image.jpegData(compressionQuality: compression) ?? data

        while compressedData.count > maxSizeKB * 1024 && compression > 0.1 {
            compression -= 0.1
            compressedData = image.jpegData(compressionQuality: compression) ?? data
        }

        // If still too large, resize the image
        if compressedData.count > maxSizeKB * 1024 {
            let scale = sqrt(Double(maxSizeKB * 1024) / Double(compressedData.count))
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            compressedData = resizedImage.jpegData(compressionQuality: 0.7) ?? compressedData
        }

        return compressedData
    }

    // MARK: - Image Generation (Nano Banana Pro)

    /// Generates renovation visualization using Nano Banana Pro (Gemini 3 Pro Image)
    /// Memory-optimized with proper error handling
    func generateImage(
        prompt: String,
        style: ImageStyle,
        aspectRatio: ImageAspectRatio
    ) async throws -> Data {
        let apiKey = try await keyManager.getGeminiAPIKey()

        // Build enhanced prompt with professional renovation visualization instructions
        let enhancedPrompt = buildNanoBananaProPrompt(basePrompt: prompt, style: style, aspectRatio: aspectRatio)

        // Create request using Nano Banana Pro's generateContent with image output
        let requestBody = GeminiImageRequest(
            contents: [
                GeminiImageRequest.Content(
                    parts: [GeminiImageRequest.Part(text: enhancedPrompt)],
                    role: "user"
                )
            ],
            generationConfig: GeminiImageRequest.GenerationConfig(
                responseModalities: ["IMAGE"],
                responseMimeType: "image/png"
            )
        )

        // Build URL for Nano Banana Pro endpoint
        guard let url = URL(string: "\(GeminiAPIConfiguration.baseURL)\(GeminiAPIConfiguration.generateImageEndpoint)?key=\(apiKey)") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        urlRequest.timeoutInterval = GeminiAPIConfiguration.imageTimeout

        logger.info("Sending image generation request to Nano Banana Pro")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Nano Banana Pro error: \(httpResponse.statusCode) - \(message)")
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        let geminiResponse = try JSONDecoder().decode(GeminiImageResponse.self, from: data)

        // Check for API error
        if let error = geminiResponse.error {
            logger.error("Nano Banana Pro error: \(error.message)")
            throw NetworkError.serverError(error.message)
        }

        // Extract image data from response
        guard let candidate = geminiResponse.candidates?.first,
              let parts = candidate.content?.parts else {
            throw NetworkError.noData
        }

        // Find the image part in the response
        for part in parts {
            if let inlineData = part.inlineData,
               let imageBytes = Data(base64Encoded: inlineData.data) {
                logger.debug("Received image from Nano Banana Pro (\(imageBytes.count) bytes)")
                return imageBytes
            }
        }

        throw NetworkError.noData
    }

    /// Builds an optimized prompt for Nano Banana Pro image generation
    private func buildNanoBananaProPrompt(basePrompt: String, style: ImageStyle, aspectRatio: ImageAspectRatio) -> String {
        let aspectRatioString: String
        switch aspectRatio {
        case .square: aspectRatioString = "1:1 square"
        case .landscape: aspectRatioString = "16:9 landscape"
        case .portrait: aspectRatioString = "9:16 portrait"
        case .wide: aspectRatioString = "21:9 ultrawide"
        }

        return """
        [NANO BANANA PRO - Professional Renovation Visualization]

        Create a photorealistic interior/exterior visualization:

        SCENE DESCRIPTION:
        \(basePrompt)

        STYLE REQUIREMENTS:
        - Visual Style: \(style.promptModifier)
        - Aspect Ratio: \(aspectRatioString)
        - Resolution: High quality, sharp details
        - Lighting: Natural, well-balanced lighting
        - Perspective: Professional architectural photography angle

        QUALITY REQUIREMENTS:
        - Photorealistic rendering with accurate materials and textures
        - Clean, modern aesthetic appropriate for renovation visualization
        - Professional interior design quality
        - No people, pets, or distracting elements
        - Focus on architectural and design elements
        - Accurate proportions and spatial relationships

        OUTPUT:
        Generate a single high-quality image suitable for professional renovation proposals.
        """
    }

    // MARK: - API Key Validation

    /// Validates the configured API key by making a test request
    /// Tries primary model first, then falls back to alternative if needed
    func validateAPIKey() async throws -> Bool {
        let apiKey = try await keyManager.getGeminiAPIKey()

        let testRequest = GeminiRequest(
            contents: [
                GeminiRequest.Content(
                    parts: [GeminiRequest.Part(text: "Respond with exactly: OK")],
                    role: "user"
                )
            ],
            generationConfig: GeminiRequest.GenerationConfig(
                temperature: 0.1,
                topP: nil,
                topK: nil,
                maxOutputTokens: 10,
                responseMimeType: nil
            ),
            safetySettings: nil
        )

        // Try with primary model first (gemini-2.5-pro)
        let primaryEndpoint = "/models/\(GeminiAPIConfiguration.textModel):generateContent"
        if let isValid = try await validateWithEndpoint(primaryEndpoint, apiKey: apiKey, request: testRequest), isValid {
            logger.info("API key validated with primary model: \(GeminiAPIConfiguration.textModel)")
            return true
        }

        // Fallback to gemini-2.5-flash if pro is not available
        let fallbackEndpoint = "/models/\(GeminiAPIConfiguration.fallbackTextModel):generateContent"
        if let isValid = try await validateWithEndpoint(fallbackEndpoint, apiKey: apiKey, request: testRequest), isValid {
            logger.info("API key validated with fallback model: \(GeminiAPIConfiguration.fallbackTextModel)")
            return true
        }

        // Try with gemini-2.0-flash as last resort
        let lastResortEndpoint = "/models/gemini-2.0-flash:generateContent"
        if let isValid = try await validateWithEndpoint(lastResortEndpoint, apiKey: apiKey, request: testRequest), isValid {
            logger.info("API key validated with gemini-2.0-flash")
            return true
        }

        return false
    }

    private func validateWithEndpoint(_ endpoint: String, apiKey: String, request: GeminiRequest) async throws -> Bool? {
        guard let url = URL(string: "\(GeminiAPIConfiguration.baseURL)\(endpoint)?key=\(apiKey)") else {
            return nil
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }

            // 401/403 means invalid API key
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                logger.error("API key authentication failed: \(httpResponse.statusCode)")
                return false
            }

            // 404 means model not found, try another
            if httpResponse.statusCode == 404 {
                logger.warning("Model not found at endpoint: \(endpoint)")
                return nil
            }

            // Check for rate limiting
            if httpResponse.statusCode == 429 {
                logger.warning("Rate limited during validation")
                // Consider it valid if rate limited - key works but quota exceeded
                return true
            }

            if httpResponse.statusCode == 200 {
                let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                return geminiResponse.error == nil && geminiResponse.candidates != nil
            }

            // Log other errors for debugging
            if let errorMessage = String(data: data, encoding: .utf8) {
                logger.error("Validation error (\(httpResponse.statusCode)): \(errorMessage)")
            }

            return nil
        } catch {
            logger.error("Validation request failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Prompt Building

    private func buildEstimatePrompt(for project: RenovationProject) -> String {
        let materialsDescription = project.selectedMaterials.isEmpty
            ? "standard materials appropriate for this renovation type"
            : project.selectedMaterials.joined(separator: ", ")

        let qualityDescription = project.qualityTier.description

        return """
        [GEMINI 3.0 PRO - BUILD PEEK Renovation Cost Estimator]

        You are BUILD PEEK's AI renovation cost estimator. Your role is to provide accurate, realistic cost estimates for home renovation projects based on current 2024-2025 market data.

        PROJECT DETAILS:
        - Project Name: \(project.projectName.isEmpty ? "Renovation Project" : project.projectName)
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

        ESTIMATION GUIDELINES:
        1. Use realistic 2024-2025 pricing (not inflated)
        2. Apply regional cost multipliers based on ZIP code
        3. Include labor at current market rates ($45-85/hr for skilled trades)
        4. Factor in material costs at retail + 15-20% contractor markup
        5. Add 10-15% contingency for unexpected issues
        6. Provide timeline in working days (not calendar days)

        COST REFERENCE (per sq ft, Standard quality):
        - Kitchen: $75-150
        - Bathroom: $70-140
        - Bedroom: $25-60
        - Living Room: $20-50
        - Basement: $25-55
        - Whole House: $50-120

        OUTPUT REQUIREMENTS:
        Return ONLY valid JSON (no markdown, no explanation). Use this exact structure:

        {
            "totalCost": {"low": <number>, "high": <number>},
            "breakdown": [
                {"category": "<Labor|Materials|Permits|Design|Contingency|Overhead>", "item": "<name>", "description": "<details>", "quantity": <number>, "unit": "<unit>", "costLow": <number>, "costHigh": <number>, "optional": <boolean>}
            ],
            "timeline": {"daysLow": <number>, "daysHigh": <number>, "recommendedSeason": "<Spring|Summer|Fall|Winter|Any>"},
            "notes": "<summary>",
            "warnings": ["<warning1>"],
            "recommendations": ["<rec1>"],
            "confidence": <0.0-1.0>,
            "regionalData": {"multiplier": <number>, "region": "<name>"}
        }

        Include 8-12 detailed line items. Be specific and realistic.
        """
    }

    private func buildVisionEstimatePrompt(for project: RenovationProject) -> String {
        let materialsDescription = project.selectedMaterials.isEmpty
            ? "analyze visible materials and suggest appropriate upgrades"
            : project.selectedMaterials.joined(separator: ", ")

        let renovationDesc = project.renovationDescription.isEmpty
            ? "general renovation and modernization"
            : project.renovationDescription

        return """
        [GEMINI 3.0 PRO - BUILD PEEK Vision-Based Cost Estimator]

        You are BUILD PEEK's AI vision estimator. Analyze the attached photos and provide an accurate renovation cost estimate.

        PHOTO ANALYSIS TASKS:
        1. Identify current room condition (excellent/good/fair/poor)
        2. Note existing materials needing replacement
        3. Estimate dimensions from visual cues
        4. Identify potential issues or complications

        PROJECT DETAILS:
        - Project: \(project.projectName.isEmpty ? "Renovation" : project.projectName)
        - Room Type: \(project.roomType.rawValue)
        - Stated Sq Ft: \(project.squareFootage > 0 ? "\(Int(project.squareFootage))" : "Estimate from photos")
        - Location: \(project.location.isEmpty ? "National Avg" : project.location)
        - ZIP: \(project.zipCode.isEmpty ? "N/A" : project.zipCode)
        - Quality: \(project.qualityTier.rawValue)
        - Materials: \(materialsDescription)
        - Description: \(renovationDesc)
        - Urgency: \(project.urgency.rawValue)
        - Permits: \(project.includesPermits ? "Yes" : "No")
        - Design: \(project.includesDesign ? "Yes" : "No")

        COST REFERENCE (2024-2025, per sq ft):
        - Kitchen: $75-150 | Bathroom: $70-140
        - Bedroom: $25-60 | Living: $20-50
        - Flooring: $5-18

        OUTPUT: Return ONLY valid JSON (no markdown):

        {
            "totalCost": {"low": <number>, "high": <number>},
            "breakdown": [
                {"category": "<Labor|Materials|Permits|Design|Contingency|Overhead>", "item": "<name>", "description": "<photo observation + recommendation>", "quantity": <number>, "unit": "<unit>", "costLow": <number>, "costHigh": <number>, "optional": <boolean>}
            ],
            "timeline": {"daysLow": <number>, "daysHigh": <number>, "recommendedSeason": "<Spring|Summer|Fall|Winter|Any>"},
            "notes": "<photo observations and recommendations>",
            "warnings": ["<issues from photos>"],
            "recommendations": ["<photo-based recommendations>"],
            "confidence": <0.0-1.0>,
            "regionalData": {"multiplier": <number>, "region": "<name>"}
        }

        Include 8-12 line items based on what you observe in the photos.
        """
    }

    private func buildImagePrompt(basePrompt: String, style: ImageStyle) -> String {
        let styleModifier = style.promptModifier
        return """
        \(basePrompt)

        Style: \(styleModifier)

        Requirements:
        - Professional interior/exterior photography quality
        - Bright, well-lit environment
        - Clean, modern aesthetic
        - High resolution and sharp details
        - No people in the image
        - Focus on architectural and design elements
        """
    }

    private func mapAspectRatio(_ ratio: ImageAspectRatio) -> String {
        switch ratio {
        case .square: return "1:1"
        case .landscape: return "16:9"
        case .portrait: return "9:16"
        case .wide: return "21:9"
        }
    }

    private func parseLooseEstimateResponse(from text: String) throws -> GeminiEstimateResponse {
        // Fallback parser for non-standard JSON responses
        // Extract key values using regex patterns

        var totalLow: Double = 0
        var totalHigh: Double = 0

        // Try to find total cost values
        if let lowMatch = text.range(of: #""low"\s*:\s*(\d+\.?\d*)"#, options: .regularExpression) {
            let value = text[lowMatch].replacingOccurrences(of: "\"low\":", with: "").trimmingCharacters(in: .whitespaces)
            totalLow = Double(value) ?? 0
        }

        if let highMatch = text.range(of: #""high"\s*:\s*(\d+\.?\d*)"#, options: .regularExpression) {
            let value = text[highMatch].replacingOccurrences(of: "\"high\":", with: "").trimmingCharacters(in: .whitespaces)
            totalHigh = Double(value) ?? 0
        }

        // Return a basic response
        return GeminiEstimateResponse(
            totalCost: GeminiEstimateResponse.CostRange(low: totalLow, high: totalHigh),
            breakdown: [],
            timeline: GeminiEstimateResponse.TimelineInfo(daysLow: 7, daysHigh: 14, recommendedSeason: "Any"),
            notes: "Estimate generated from AI response. Please review the breakdown for detailed costs.",
            warnings: nil,
            recommendations: nil,
            confidence: 0.7,
            regionalData: nil
        )
    }
}

// MARK: - Mock Service for Previews/Testing

/// Mock Gemini API service for SwiftUI previews and unit testing
final class MockGeminiAPIService: GeminiAPIServiceProtocol {

    let shouldFail: Bool
    let simulatedDelay: TimeInterval

    init(shouldFail: Bool = false, simulatedDelay: TimeInterval = 1.0) {
        self.shouldFail = shouldFail
        self.simulatedDelay = simulatedDelay
    }

    func generateEstimateWithImages(for project: RenovationProject, images: [Data]) async throws -> GeminiEstimateResponse {
        // Use the same logic as generateEstimate but with slightly higher confidence
        var estimate = try await generateEstimate(for: project)
        // Vision-based estimates have higher confidence when images are provided
        return GeminiEstimateResponse(
            totalCost: estimate.totalCost,
            breakdown: estimate.breakdown,
            timeline: estimate.timeline,
            notes: "Vision-based analysis: \(estimate.notes)",
            warnings: estimate.warnings,
            recommendations: estimate.recommendations,
            confidence: 0.92,
            regionalData: estimate.regionalData
        )
    }

    func generateVisualization(currentImages: [Data], description: String, style: ImageStyle) async throws -> Data {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))

        if shouldFail {
            throw NetworkError.serverError("Mock visualization error")
        }

        // Return a placeholder visualization image
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Gradient background
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

            // Text overlay
            let text = "Visualization Preview"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let point = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            text.draw(at: point, withAttributes: attributes)
        }

        return image.pngData() ?? Data()
    }

    func generateEstimate(for project: RenovationProject) async throws -> GeminiEstimateResponse {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))

        if shouldFail {
            throw NetworkError.serverError("Mock error")
        }

        let sqft = max(project.squareFootage, 100)
        let baseCostPerSqFt = project.roomType.averageCostPerSqFt.lowerBound
        let multiplier = project.qualityTier.multiplier

        let baseCost = sqft * baseCostPerSqFt * multiplier

        return GeminiEstimateResponse(
            totalCost: GeminiEstimateResponse.CostRange(
                low: baseCost * 0.85,
                high: baseCost * 1.15
            ),
            breakdown: [
                GeminiEstimateResponse.BreakdownItem(
                    category: "Labor",
                    item: "General Labor",
                    description: "Skilled labor for \(project.roomType.rawValue) renovation",
                    quantity: sqft,
                    unit: "sq ft",
                    costLow: baseCost * 0.4 * 0.85,
                    costHigh: baseCost * 0.4 * 1.15,
                    optional: false
                ),
                GeminiEstimateResponse.BreakdownItem(
                    category: "Materials",
                    item: "Primary Materials",
                    description: "Main materials for renovation",
                    quantity: sqft,
                    unit: "sq ft",
                    costLow: baseCost * 0.35 * 0.85,
                    costHigh: baseCost * 0.35 * 1.15,
                    optional: false
                ),
                GeminiEstimateResponse.BreakdownItem(
                    category: "Permits",
                    item: "Building Permits",
                    description: "Required permits and inspections",
                    quantity: 1,
                    unit: "lot",
                    costLow: 500,
                    costHigh: 1500,
                    optional: false
                ),
                GeminiEstimateResponse.BreakdownItem(
                    category: "Contingency",
                    item: "Contingency Fund",
                    description: "10% contingency for unexpected costs",
                    quantity: 1,
                    unit: "lot",
                    costLow: baseCost * 0.1,
                    costHigh: baseCost * 0.1,
                    optional: false
                )
            ],
            timeline: GeminiEstimateResponse.TimelineInfo(
                daysLow: max(7, Int(sqft / 50)),
                daysHigh: max(14, Int(sqft / 30)),
                recommendedSeason: "Spring"
            ),
            notes: "This is a mock estimate for testing purposes. Actual costs may vary based on specific requirements, local labor rates, and material availability.",
            warnings: ["Prices based on national averages", "Local costs may vary significantly"],
            recommendations: ["Get multiple contractor quotes", "Consider phased approach for large projects"],
            confidence: 0.85,
            regionalData: GeminiEstimateResponse.RegionalData(multiplier: 1.0, region: "National Average")
        )
    }

    func generateImage(prompt: String, style: ImageStyle, aspectRatio: ImageAspectRatio) async throws -> Data {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))

        if shouldFail {
            throw NetworkError.serverError("Mock error")
        }

        // Return a placeholder image
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let text = "Generated Image"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 32),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let point = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            text.draw(at: point, withAttributes: attributes)
        }

        return image.pngData() ?? Data()
    }

    func validateAPIKey() async throws -> Bool {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        return !shouldFail
    }
}
