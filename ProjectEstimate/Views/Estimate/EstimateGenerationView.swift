//
//  EstimateGenerationView.swift
//  ProjectEstimate
//
//  AI-powered estimate generation with real-time progress
//  Displays detailed cost breakdowns with charts
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Estimate Generation View

struct EstimateGenerationView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProjectViewModel

    @State private var showImageGenerator = false
    @State private var showPDFExport = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var selectedBreakdownItem: EstimateLineItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isGeneratingEstimate {
                    generatingView
                } else if let estimate = viewModel.currentEstimate {
                    estimateResultView(estimate)
                } else {
                    startGenerationView
                }
            }
            .navigationTitle(viewModel.isGeneratingEstimate ? "Generating..." : "Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if viewModel.currentEstimate != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showImageGenerator = true
                            } label: {
                                Label("Generate Image", systemImage: "photo")
                            }

                            Button {
                                showPDFExport = true
                            } label: {
                                Label("Export PDF", systemImage: "doc.fill")
                            }

                            Button {
                                prepareShareContent()
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showImageGenerator) {
            ImageGeneratorSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showPDFExport) {
            PDFExportSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .onAppear {
            if viewModel.currentEstimate == nil && !viewModel.isGeneratingEstimate {
                Task {
                    await viewModel.generateEstimate()
                }
            }
        }
    }

    // MARK: - Start Generation View

    private var startGenerationView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Ready to Generate")
                    .font(.title2.bold())

                Text("AI will analyze your project and provide a detailed estimate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await viewModel.generateEstimate()
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Estimate")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
    }

    // MARK: - Generating View

    private var generatingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated loading indicator
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: viewModel.estimateProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: viewModel.estimateProgress)

                VStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.title)
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse, options: .repeating)

                    Text("\(Int(viewModel.estimateProgress * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text("Analyzing Your Project")
                    .font(.title3.bold())

                Text(viewModel.estimateStatusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut, value: viewModel.estimateStatusMessage)
            }

            // Progress steps
            VStack(alignment: .leading, spacing: 12) {
                ProgressStepRow(
                    title: "Analyzing requirements",
                    isComplete: viewModel.estimateProgress >= 0.2,
                    isActive: viewModel.estimateProgress < 0.2
                )

                ProgressStepRow(
                    title: "Calculating costs",
                    isComplete: viewModel.estimateProgress >= 0.5,
                    isActive: viewModel.estimateProgress >= 0.2 && viewModel.estimateProgress < 0.5
                )

                ProgressStepRow(
                    title: "Generating breakdown",
                    isComplete: viewModel.estimateProgress >= 0.8,
                    isActive: viewModel.estimateProgress >= 0.5 && viewModel.estimateProgress < 0.8
                )

                ProgressStepRow(
                    title: "Finalizing estimate",
                    isComplete: viewModel.estimateProgress >= 1.0,
                    isActive: viewModel.estimateProgress >= 0.8 && viewModel.estimateProgress < 1.0
                )
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Estimate Result View

    private func estimateResultView(_ estimate: EstimateResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero cost card
                costHeroCard(estimate)
                    .fadeSlideIn(delay: 0.05)

                // Cost breakdown chart
                costBreakdownSection(estimate)
                    .fadeSlideIn(delay: 0.1)

                // Timeline
                timelineSection(estimate)
                    .fadeSlideIn(delay: 0.15)

                // Line items
                lineItemsSection(estimate)
                    .fadeSlideIn(delay: 0.2)

                // Recommendations
                if !estimate.recommendations.isEmpty {
                    recommendationsSection(estimate)
                        .fadeSlideIn(delay: 0.25)
                }

                // Warnings
                if !estimate.warnings.isEmpty {
                    warningsSection(estimate)
                        .fadeSlideIn(delay: 0.3)
                }

                // Action buttons
                actionButtons
                    .fadeSlideIn(delay: 0.35)

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }

    // MARK: - Cost Hero Card

    private func costHeroCard(_ estimate: EstimateResult) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Total Estimated Cost")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(estimate.formattedTotalRange)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Timeline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(estimate.formattedTimeline)
                        .font(.subheadline.bold())
                }

                Divider()
                    .frame(height: 30)

                VStack(spacing: 4) {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(estimate.confidenceScore * 100))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }

                Divider()
                    .frame(height: 30)

                VStack(spacing: 4) {
                    Text("Region")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(estimate.regionName.isEmpty ? "National" : estimate.regionName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.15), .purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Cost Breakdown Section

    private func costBreakdownSection(_ estimate: EstimateResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost Breakdown")
                .font(.headline)

            CostBreakdownPieChart(data: estimate.costBreakdown)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Timeline Section

    private func timelineSection(_ estimate: EstimateResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Timeline")
                .font(.headline)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estimated Duration")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(estimate.formattedTimeline)
                            .font(.title3.bold())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Best Season")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(estimate.recommendedStartSeason)
                            .font(.title3.bold())
                    }
                }

                // Timeline bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * 0.7)
                    }
                }
                .frame(height: 12)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Line Items Section

    private func lineItemsSection(_ estimate: EstimateResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Detailed Breakdown")
                    .font(.headline)

                Spacer()

                Text("\(estimate.lineItems.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(estimate.lineItems.enumerated()), id: \.element.id) { index, item in
                    LineItemRow(item: item) {
                        selectedBreakdownItem = item
                    }

                    if index < estimate.lineItems.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Recommendations Section

    private func recommendationsSection(_ estimate: EstimateResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recommendations", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(estimate.recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)

                        Text(recommendation)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Warnings Section

    private func warningsSection(_ estimate: EstimateResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Important Notes", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(estimate.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)

                        Text(warning)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showImageGenerator = true
            } label: {
                HStack {
                    Image(systemName: "photo.fill")
                    Text("Generate Visualization")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                showPDFExport = true
            } label: {
                HStack {
                    Image(systemName: "doc.fill")
                    Text("Export PDF Report")
                }
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Share Functionality

    private func prepareShareContent() {
        guard let estimate = viewModel.currentEstimate,
              let project = viewModel.currentProject else { return }

        let projectName = project.projectName.isEmpty ? "Renovation Project" : project.projectName
        let shareText = """
        📋 \(projectName) Estimate

        🏠 Room Type: \(project.roomType.rawValue)
        📐 Square Footage: \(Int(project.squareFootage)) sq ft
        ⭐ Quality: \(project.qualityTier.rawValue)

        💰 Estimated Cost: \(estimate.formattedTotalRange)
        📅 Timeline: \(estimate.formattedTimeline)
        🎯 Confidence: \(Int(estimate.confidenceScore * 100))%

        Generated with ProjectEstimate
        """

        shareItems = [shareText]
        showShareSheet = true
    }
}

// MARK: - Share Sheet (UIKit wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Supporting Views

struct ProgressStepRow: View {
    let title: String
    let isComplete: Bool
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : (isActive ? Color.blue : Color(.systemGray4)))
                    .frame(width: 24, height: 24)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else if isActive {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                }
            }

            Text(title)
                .font(.subheadline)
                .foregroundStyle(isComplete || isActive ? .primary : .secondary)

            Spacer()
        }
    }
}

struct LineItemRow: View {
    let item: EstimateLineItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(item.itemName)
                            .font(.subheadline.weight(.medium))

                        if item.isOptional {
                            Text("Optional")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Text(item.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(item.formattedCostRange)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Image Generator Sheet

struct ImageGeneratorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProjectViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Style picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Style")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(ImageStyle.allCases) { style in
                                StyleButton(
                                    style: style,
                                    isSelected: viewModel.selectedImageStyle == style
                                ) {
                                    viewModel.selectedImageStyle = style
                                }
                            }
                        }
                    }

                    // Aspect ratio picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Aspect Ratio")
                            .font(.headline)

                        HStack(spacing: 12) {
                            ForEach(ImageAspectRatio.allCases) { ratio in
                                AspectRatioButton(
                                    ratio: ratio,
                                    isSelected: viewModel.selectedAspectRatio == ratio
                                ) {
                                    viewModel.selectedAspectRatio = ratio
                                }
                            }
                        }
                    }

                    // Prompt
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Description")
                            .font(.headline)

                        TextEditor(text: $viewModel.imagePrompt)
                            .frame(minHeight: 100)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Generate button
                    Button {
                        Task {
                            await viewModel.generateImage()
                        }
                    } label: {
                        HStack {
                            if viewModel.isGeneratingImage {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                            Text(viewModel.isGeneratingImage ? "Generating..." : "Generate Image")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(viewModel.isGeneratingImage || viewModel.imagePrompt.isEmpty)

                    // Generated images
                    if !viewModel.generatedImages.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Generated Images")
                                .font(.headline)

                            ForEach(viewModel.generatedImages) { image in
                                if let uiImage = image.uiImage {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Generate Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StyleButton: View {
    let style: ImageStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(style.rawValue)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.purple : Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct AspectRatioButton: View {
    let ratio: ImageAspectRatio
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(ratio.displayName)
                .font(.caption)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.purple : Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
        }
    }
}

// MARK: - PDF Export Sheet

struct PDFExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProjectViewModel

    @State private var isExporting = false
    @State private var exportedURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("Export PDF Report")
                        .font(.title2.bold())

                    Text("Generate a professional PDF with your estimate details and visualizations")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Includes:")
                        .font(.headline)

                    ForEach(["Project summary", "Cost breakdown", "Timeline", "Line items", "Recommendations", "Generated images"], id: \.self) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(item)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()

                Button {
                    exportPDF()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isExporting ? "Generating..." : "Generate PDF")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isExporting)
            }
            .padding()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func exportPDF() {
        isExporting = true

        Task {
            guard let project = viewModel.currentProject,
                  let estimate = viewModel.currentEstimate else {
                isExporting = false
                return
            }

            let pdfService = PDFExportService()
            do {
                let pdfData = try await pdfService.generateEstimatePDF(
                    project: project,
                    estimate: estimate,
                    images: viewModel.generatedImages,
                    configuration: .standard
                )

                // Save to temp file
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("estimate_\(project.id.uuidString).pdf")

                try pdfData.write(to: url)
                exportedURL = url

                // Present share sheet
                await MainActor.run {
                    isExporting = false
                    // Share the PDF
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    viewModel.error = error
                    viewModel.showError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Estimate Generation") {
    EstimateGenerationView(
        viewModel: ProjectViewModel(
            modelContext: try! ModelContainer(for: RenovationProject.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext,
            geminiService: GeminiAPIService()
        )
    )
    .environment(AppState.shared)
}
