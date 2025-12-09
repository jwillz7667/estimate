//
//  PDFExportService.swift
//  ProjectEstimate
//
//  Professional PDF export service for renovation estimates
//  Generates branded, print-ready documents with cost breakdowns and visualizations
//

import Foundation
import UIKit
import PDFKit
import OSLog

// MARK: - PDF Export Configuration

struct PDFConfiguration: Sendable {
    let pageSize: CGSize
    let margins: UIEdgeInsets
    let brandColor: UIColor
    let companyName: String
    let companyLogo: UIImage?
    let includeWatermark: Bool

    static let standard = PDFConfiguration(
        pageSize: CGSize(width: 612, height: 792), // Letter size
        margins: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
        brandColor: .systemBlue,
        companyName: "RenovationEstimator Pro",
        companyLogo: nil,
        includeWatermark: false
    )

    static let a4 = PDFConfiguration(
        pageSize: CGSize(width: 595, height: 842), // A4 size
        margins: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
        brandColor: .systemBlue,
        companyName: "RenovationEstimator Pro",
        companyLogo: nil,
        includeWatermark: false
    )
}

// MARK: - PDF Export Service Protocol

protocol PDFExportServiceProtocol: Sendable {
    func generateEstimatePDF(
        project: RenovationProject,
        estimate: EstimateResult,
        images: [GeneratedImage],
        configuration: PDFConfiguration
    ) async throws -> Data
}

// MARK: - PDF Export Service

/// Professional PDF generation service for renovation estimates
final class PDFExportService: PDFExportServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.projectestimate", category: "PDFExport")
    private let dateFormatter: DateFormatter
    private let currencyFormatter: NumberFormatter

    // MARK: - Initialization

    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.maximumFractionDigits = 0
    }

    // MARK: - Public Methods

    /// Generates a complete PDF document for a renovation estimate
    @MainActor
    func generateEstimatePDF(
        project: RenovationProject,
        estimate: EstimateResult,
        images: [GeneratedImage],
        configuration: PDFConfiguration
    ) async throws -> Data {
        logger.info("Starting PDF generation for project: \(project.projectName)")

        let pageSize = configuration.pageSize
        let margins = configuration.margins
        let contentWidth = pageSize.width - margins.left - margins.right
        let contentHeight = pageSize.height - margins.top - margins.bottom

        // Create PDF context
        let pdfData = NSMutableData()

        UIGraphicsBeginPDFContextToData(pdfData, CGRect(origin: .zero, size: pageSize), pdfMetadata(for: project))

        var currentY: CGFloat = 0

        // Page 1: Cover & Summary
        UIGraphicsBeginPDFPage()
        currentY = margins.top

        currentY = drawHeader(
            at: CGPoint(x: margins.left, y: currentY),
            width: contentWidth,
            configuration: configuration
        )

        currentY = drawTitle(
            project: project,
            at: CGPoint(x: margins.left, y: currentY + 30),
            width: contentWidth
        )

        currentY = drawSummarySection(
            project: project,
            estimate: estimate,
            at: CGPoint(x: margins.left, y: currentY + 20),
            width: contentWidth
        )

        currentY = drawCostSummary(
            estimate: estimate,
            at: CGPoint(x: margins.left, y: currentY + 30),
            width: contentWidth
        )

        // Page 2: Detailed Breakdown
        UIGraphicsBeginPDFPage()
        currentY = margins.top

        currentY = drawPageHeader(
            title: "Detailed Cost Breakdown",
            at: CGPoint(x: margins.left, y: currentY),
            width: contentWidth,
            configuration: configuration
        )

        currentY = drawLineItems(
            estimate: estimate,
            at: CGPoint(x: margins.left, y: currentY + 20),
            width: contentWidth,
            maxY: pageSize.height - margins.bottom
        )

        // Page 3: Timeline & Recommendations
        UIGraphicsBeginPDFPage()
        currentY = margins.top

        currentY = drawPageHeader(
            title: "Timeline & Recommendations",
            at: CGPoint(x: margins.left, y: currentY),
            width: contentWidth,
            configuration: configuration
        )

        currentY = drawTimeline(
            estimate: estimate,
            at: CGPoint(x: margins.left, y: currentY + 20),
            width: contentWidth
        )

        currentY = drawRecommendations(
            estimate: estimate,
            at: CGPoint(x: margins.left, y: currentY + 30),
            width: contentWidth
        )

        currentY = drawWarnings(
            estimate: estimate,
            at: CGPoint(x: margins.left, y: currentY + 30),
            width: contentWidth
        )

        // Page 4: Visualizations (if images available)
        if !images.isEmpty {
            UIGraphicsBeginPDFPage()
            currentY = margins.top

            currentY = drawPageHeader(
                title: "Project Visualizations",
                at: CGPoint(x: margins.left, y: currentY),
                width: contentWidth,
                configuration: configuration
            )

            currentY = drawImages(
                images: images,
                at: CGPoint(x: margins.left, y: currentY + 20),
                width: contentWidth,
                maxHeight: contentHeight - 60
            )
        }

        // Footer on last page
        drawFooter(
            at: CGPoint(x: margins.left, y: pageSize.height - margins.bottom + 10),
            width: contentWidth,
            configuration: configuration
        )

        UIGraphicsEndPDFContext()

        logger.info("PDF generation completed (\(pdfData.length) bytes)")

        return pdfData as Data
    }

    // MARK: - Drawing Methods

    private func drawHeader(
        at point: CGPoint,
        width: CGFloat,
        configuration: PDFConfiguration
    ) -> CGFloat {
        var currentY = point.y

        // Draw logo if available
        if let logo = configuration.companyLogo {
            let logoSize = CGSize(width: 60, height: 60)
            logo.draw(in: CGRect(origin: point, size: logoSize))
            currentY += logoSize.height + 10
        }

        // Company name
        let companyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: configuration.brandColor
        ]

        configuration.companyName.draw(
            at: CGPoint(x: point.x, y: currentY),
            withAttributes: companyAttributes
        )

        currentY += 35

        // Divider line
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: point.x, y: currentY))
        linePath.addLine(to: CGPoint(x: point.x + width, y: currentY))
        configuration.brandColor.setStroke()
        linePath.lineWidth = 2
        linePath.stroke()

        return currentY + 10
    }

    private func drawTitle(
        project: RenovationProject,
        at point: CGPoint,
        width: CGFloat
    ) -> CGFloat {
        var currentY = point.y

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 28),
            .foregroundColor: UIColor.black
        ]

        "Renovation Estimate".draw(
            at: CGPoint(x: point.x, y: currentY),
            withAttributes: titleAttributes
        )

        currentY += 40

        // Project name
        let projectNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20),
            .foregroundColor: UIColor.darkGray
        ]

        let projectName = project.projectName.isEmpty ? "Untitled Project" : project.projectName
        projectName.draw(
            at: CGPoint(x: point.x, y: currentY),
            withAttributes: projectNameAttributes
        )

        currentY += 30

        // Date
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.gray
        ]

        let dateString = "Generated: \(dateFormatter.string(from: Date()))"
        dateString.draw(
            at: CGPoint(x: point.x, y: currentY),
            withAttributes: dateAttributes
        )

        return currentY + 20
    }

    private func drawSummarySection(
        project: RenovationProject,
        estimate: EstimateResult,
        at point: CGPoint,
        width: CGFloat
    ) -> CGFloat {
        var currentY = point.y

        let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]

        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]

        "Project Details".draw(at: CGPoint(x: point.x, y: currentY), withAttributes: sectionTitleAttributes)
        currentY += 25

        let details = [
            ("Room Type:", project.roomType.rawValue),
            ("Square Footage:", "\(Int(project.squareFootage)) sq ft"),
            ("Quality Tier:", project.qualityTier.rawValue),
            ("Location:", project.location.isEmpty ? "Not specified" : project.location),
            ("Urgency:", project.urgency.rawValue)
        ]

        for (label, value) in details {
            let labelWidth: CGFloat = 120

            label.draw(
                in: CGRect(x: point.x, y: currentY, width: labelWidth, height: 20),
                withAttributes: detailAttributes
            )

            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]

            value.draw(
                at: CGPoint(x: point.x + labelWidth, y: currentY),
                withAttributes: valueAttributes
            )

            currentY += 18
        }

        return currentY
    }

    private func drawCostSummary(
        estimate: EstimateResult,
        at point: CGPoint,
        width: CGFloat
    ) -> CGFloat {
        var currentY = point.y

        // Background box
        let boxRect = CGRect(x: point.x, y: currentY, width: width, height: 120)
        UIColor.systemBlue.withAlphaComponent(0.1).setFill()
        UIBezierPath(roundedRect: boxRect, cornerRadius: 8).fill()

        currentY += 15

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.systemBlue
        ]

        "Total Estimated Cost".draw(
            at: CGPoint(x: point.x + 15, y: currentY),
            withAttributes: titleAttributes
        )

        currentY += 30

        // Cost range
        let costAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 32),
            .foregroundColor: UIColor.black
        ]

        estimate.formattedTotalRange.draw(
            at: CGPoint(x: point.x + 15, y: currentY),
            withAttributes: costAttributes
        )

        currentY += 45

        // Confidence
        let confidenceAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.gray
        ]

        let confidenceText = "Confidence: \(Int(estimate.confidenceScore * 100))% | Timeline: \(estimate.formattedTimeline)"
        confidenceText.draw(
            at: CGPoint(x: point.x + 15, y: currentY),
            withAttributes: confidenceAttributes
        )

        return currentY + 30
    }

    private func drawPageHeader(
        title: String,
        at point: CGPoint,
        width: CGFloat,
        configuration: PDFConfiguration
    ) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: configuration.brandColor
        ]

        title.draw(at: point, withAttributes: attributes)

        let lineY = point.y + 28

        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: point.x, y: lineY))
        linePath.addLine(to: CGPoint(x: point.x + width, y: lineY))
        configuration.brandColor.withAlphaComponent(0.5).setStroke()
        linePath.lineWidth = 1
        linePath.stroke()

        return lineY + 5
    }

    private func drawLineItems(
        estimate: EstimateResult,
        at point: CGPoint,
        width: CGFloat,
        maxY: CGFloat
    ) -> CGFloat {
        var currentY = point.y

        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]

        let itemAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]

        let descAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.darkGray
        ]

        // Column headers
        let columns: [(String, CGFloat)] = [
            ("ITEM", 0),
            ("CATEGORY", width * 0.35),
            ("QTY", width * 0.55),
            ("COST RANGE", width * 0.70)
        ]

        for (header, x) in columns {
            header.draw(at: CGPoint(x: point.x + x, y: currentY), withAttributes: headerAttributes)
        }

        currentY += 20

        // Draw each line item
        for item in estimate.lineItems {
            if currentY > maxY - 50 {
                break
            }

            // Item name
            item.itemName.draw(
                in: CGRect(x: point.x, y: currentY, width: width * 0.33, height: 30),
                withAttributes: itemAttributes
            )

            // Category
            item.category.draw(
                at: CGPoint(x: point.x + width * 0.35, y: currentY),
                withAttributes: itemAttributes
            )

            // Quantity
            let qtyText = "\(Int(item.quantity)) \(item.unit)"
            qtyText.draw(
                at: CGPoint(x: point.x + width * 0.55, y: currentY),
                withAttributes: itemAttributes
            )

            // Cost
            item.formattedCostRange.draw(
                at: CGPoint(x: point.x + width * 0.70, y: currentY),
                withAttributes: itemAttributes
            )

            currentY += 15

            // Description
            item.description.draw(
                in: CGRect(x: point.x + 10, y: currentY, width: width * 0.65, height: 25),
                withAttributes: descAttributes
            )

            currentY += 25
        }

        return currentY
    }

    private func drawTimeline(
        estimate: EstimateResult,
        at point: CGPoint,
        width: CGFloat
    ) -> CGFloat {
        var currentY = point.y

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]

        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]

        "Estimated Timeline".draw(at: CGPoint(x: point.x, y: currentY), withAttributes: titleAttributes)
        currentY += 25

        let timelineText = "Duration: \(estimate.formattedTimeline)\nRecommended Start: \(estimate.recommendedStartSeason)"
        timelineText.draw(
            in: CGRect(x: point.x, y: currentY, width: width, height: 50),
            withAttributes: valueAttributes
        )

        return currentY + 50
    }

    private func drawRecommendations(
        estimate: EstimateResult,
        at point: CGPoint,
        width: CGFloat
    ) -> CGFloat {
        var currentY = point.y

        guard !estimate.recommendations.isEmpty else { return currentY }

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.systemGreen
        ]

        let bulletAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]

        "Recommendations".draw(at: CGPoint(x: point.x, y: currentY), withAttributes: titleAttributes)
        currentY += 22

        for recommendation in estimate.recommendations {
            let bullet = "• \(recommendation)"
            bullet.draw(
                in: CGRect(x: point.x + 10, y: currentY, width: width - 20, height: 40),
                withAttributes: bulletAttributes
            )
            currentY += 20
        }

        return currentY
    }

    private func drawWarnings(
        estimate: EstimateResult,
        at point: CGPoint,
        width: CGFloat
    ) -> CGFloat {
        var currentY = point.y

        guard !estimate.warnings.isEmpty else { return currentY }

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.systemOrange
        ]

        let bulletAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]

        "Important Notes".draw(at: CGPoint(x: point.x, y: currentY), withAttributes: titleAttributes)
        currentY += 22

        for warning in estimate.warnings {
            let bullet = "⚠️ \(warning)"
            bullet.draw(
                in: CGRect(x: point.x + 10, y: currentY, width: width - 20, height: 40),
                withAttributes: bulletAttributes
            )
            currentY += 20
        }

        return currentY
    }

    private func drawImages(
        images: [GeneratedImage],
        at point: CGPoint,
        width: CGFloat,
        maxHeight: CGFloat
    ) -> CGFloat {
        var currentY = point.y

        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]

        for (index, generatedImage) in images.prefix(2).enumerated() {
            guard let image = generatedImage.uiImage else { continue }

            let aspectRatio = image.size.width / image.size.height
            let imageWidth = min(width, 400)
            let imageHeight = imageWidth / aspectRatio

            if currentY + imageHeight > point.y + maxHeight {
                break
            }

            let imageRect = CGRect(
                x: point.x + (width - imageWidth) / 2,
                y: currentY,
                width: imageWidth,
                height: imageHeight
            )

            image.draw(in: imageRect)

            currentY += imageHeight + 10

            // Caption
            let caption = generatedImage.title.isEmpty
                ? "Visualization \(index + 1)"
                : generatedImage.title

            let captionWidth = caption.size(withAttributes: captionAttributes).width
            caption.draw(
                at: CGPoint(x: point.x + (width - captionWidth) / 2, y: currentY),
                withAttributes: captionAttributes
            )

            currentY += 30
        }

        return currentY
    }

    private func drawFooter(
        at point: CGPoint,
        width: CGFloat,
        configuration: PDFConfiguration
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.gray
        ]

        let footerText = "Generated by \(configuration.companyName) • This estimate is for informational purposes only"
        let textWidth = footerText.size(withAttributes: attributes).width
        let centerX = point.x + (width - textWidth) / 2

        footerText.draw(at: CGPoint(x: centerX, y: point.y), withAttributes: attributes)
    }

    private func pdfMetadata(for project: RenovationProject) -> [String: Any] {
        [
            kCGPDFContextTitle as String: "Renovation Estimate - \(project.projectName)",
            kCGPDFContextAuthor as String: "RenovationEstimator Pro",
            kCGPDFContextCreator as String: "RenovationEstimator Pro iOS App",
            kCGPDFContextSubject as String: "\(project.roomType.rawValue) Renovation Estimate"
        ]
    }
}
