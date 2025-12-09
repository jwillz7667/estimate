//
//  GeneratedImage.swift
//  ProjectEstimate
//
//  Model for AI-generated renovation visualization images
//  Supports Imagen API integration with local caching
//

import Foundation
import SwiftData
import UIKit

/// Represents an AI-generated renovation visualization image
@Model
final class GeneratedImage: @unchecked Sendable {
    var id: UUID
    var createdAt: Date

    // MARK: - Image Data
    var imageData: Data?
    var thumbnailData: Data?
    var imageURL: String?

    // MARK: - Generation Details
    var prompt: String
    var style: ImageStyle
    var aspectRatio: ImageAspectRatio
    var generationDurationSeconds: Double

    // MARK: - Metadata
    var title: String
    var notes: String
    var isFavorite: Bool

    // MARK: - Relationship
    var project: RenovationProject?

    init(
        id: UUID = UUID(),
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        imageURL: String? = nil,
        prompt: String = "",
        style: ImageStyle = .photorealistic,
        aspectRatio: ImageAspectRatio = .landscape,
        generationDurationSeconds: Double = 0,
        title: String = "",
        notes: String = "",
        isFavorite: Bool = false
    ) {
        self.id = id
        self.createdAt = Date()
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.imageURL = imageURL
        self.prompt = prompt
        self.style = style
        self.aspectRatio = aspectRatio
        self.generationDurationSeconds = generationDurationSeconds
        self.title = title
        self.notes = notes
        self.isFavorite = isFavorite
    }

    /// Loads UIImage from stored data
    @MainActor
    var uiImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }

    /// Loads thumbnail UIImage from stored data
    @MainActor
    var thumbnailImage: UIImage? {
        guard let thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }

    /// Generates thumbnail from full image
    @MainActor
    func generateThumbnail(targetSize: CGSize = CGSize(width: 200, height: 200)) {
        guard let image = uiImage else { return }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        thumbnailData = thumbnail.jpegData(compressionQuality: 0.7)
    }
}

// MARK: - Enums

enum ImageStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case photorealistic = "Photorealistic"
    case architectural = "Architectural Rendering"
    case sketch = "Sketch/Blueprint"
    case modern = "Modern Minimalist"
    case traditional = "Traditional"
    case industrial = "Industrial"
    case scandinavian = "Scandinavian"
    case coastal = "Coastal"

    var id: String { rawValue }

    var promptModifier: String {
        switch self {
        case .photorealistic:
            return "photorealistic, high-resolution photograph, professional interior photography, natural lighting"
        case .architectural:
            return "architectural 3D rendering, professional visualization, clean lines, accurate proportions"
        case .sketch:
            return "architectural sketch, blueprint style, technical drawing, pencil rendering"
        case .modern:
            return "modern minimalist design, clean aesthetic, contemporary style, sleek finishes"
        case .traditional:
            return "traditional style, classic design elements, warm and inviting, timeless elegance"
        case .industrial:
            return "industrial style, exposed elements, raw materials, urban loft aesthetic"
        case .scandinavian:
            return "scandinavian design, light and airy, natural materials, hygge atmosphere"
        case .coastal:
            return "coastal style, beach-inspired, light colors, relaxed atmosphere"
        }
    }
}

enum ImageAspectRatio: String, Codable, CaseIterable, Identifiable, Sendable {
    case square = "1:1"
    case landscape = "16:9"
    case portrait = "9:16"
    case wide = "21:9"

    var id: String { rawValue }

    var dimensions: (width: Int, height: Int) {
        switch self {
        case .square: return (1024, 1024)
        case .landscape: return (1792, 1024)
        case .portrait: return (1024, 1792)
        case .wide: return (2016, 864)
        }
    }

    var displayName: String {
        switch self {
        case .square: return "Square"
        case .landscape: return "Landscape"
        case .portrait: return "Portrait"
        case .wide: return "Wide"
        }
    }
}

// MARK: - API Response DTO

/// DTO for parsing Imagen API response
struct ImagenAPIResponse: Codable, Sendable {
    let predictions: [Prediction]?
    let error: APIError?

    struct Prediction: Codable, Sendable {
        let bytesBase64Encoded: String?
        let mimeType: String?
    }

    struct APIError: Codable, Sendable {
        let code: Int
        let message: String
        let status: String
    }
}

/// Alternative response format for different API versions
struct ImagenGenerateResponse: Codable, Sendable {
    let images: [GeneratedImageData]?
    let error: String?

    struct GeneratedImageData: Codable, Sendable {
        let base64: String
        let mimeType: String?
        let width: Int?
        let height: Int?
    }
}
