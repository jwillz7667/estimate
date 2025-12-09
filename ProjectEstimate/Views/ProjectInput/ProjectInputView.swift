//
//  ProjectInputView.swift
//  BuildPeek
//
//  Professional project input form with BUILD PEEK design
//  Clean, modern UI with smooth micro-animations
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Project Input View

struct ProjectInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    // Optional preselected room type from quick actions
    var preselectedRoomType: RoomType?

    @State private var viewModel: ProjectViewModel?
    @State private var currentStep: FormStep = .photos
    @State private var showEstimateView = false

    // Photo picker state
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false

    enum FormStep: Int, CaseIterable {
        case photos = 0
        case basics = 1
        case details = 2
        case materials = 3
        case review = 4

        var title: String {
            switch self {
            case .photos: return "Photos"
            case .basics: return "Basics"
            case .details: return "Details"
            case .materials: return "Materials"
            case .review: return "Review"
            }
        }

        var icon: String {
            switch self {
            case .photos: return "camera"
            case .basics: return "house"
            case .details: return "ruler"
            case .materials: return "shippingbox"
            case .review: return "checkmark.circle"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Clean background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress indicator
                    StepProgressView(
                        steps: FormStep.allCases.map { $0.title },
                        currentStep: currentStep.rawValue
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Form content
                    TabView(selection: $currentStep) {
                        photosStep
                            .tag(FormStep.photos)

                        basicsStep
                            .tag(FormStep.basics)

                        detailsStep
                            .tag(FormStep.details)

                        materialsStep
                            .tag(FormStep.materials)

                        reviewStep
                            .tag(FormStep.review)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)

                    // Navigation buttons
                    navigationButtons
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("New Peek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if viewModel == nil {
                    let vm = ProjectViewModel(
                        modelContext: modelContext,
                        geminiService: DIContainer.shared.geminiService
                    )
                    // Apply preselected room type if provided from quick actions
                    if let roomType = preselectedRoomType {
                        vm.updateRoomType(roomType)
                    }
                    viewModel = vm
                }
            }
        }
        .fullScreenCover(isPresented: $showEstimateView) {
            if let vm = viewModel {
                EstimateGenerationView(viewModel: vm)
            }
        }
    }

    // MARK: - Step 0: Photos

    private var photosStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero section
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundStyle(BuildPeekColors.primaryBlue)

                    Text("Upload Photos of Your Space")
                        .font(BuildPeekTypography.headlineLarge)
                        .multilineTextAlignment(.center)

                    Text("Snap photos of your renovation area. BUILD PEEK AI will analyze them for accurate estimates and show you what your finished project will look like.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                .fadeSlideIn(delay: 0.05)

                // Photo picker - limited to 3 photos for memory optimization
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 3,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 16) {
                        if (viewModel?.formState.uploadedImages ?? []).isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundStyle(BuildPeekColors.primaryBlue)

                                Text("Tap to Add Photos")
                                    .font(.headline)

                                Text("Up to 3 photos")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .background(BuildPeekColors.primaryBlue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                                    .foregroundStyle(BuildPeekColors.primaryBlue.opacity(0.5))
                            )
                        } else {
                            // Show uploaded photos
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach((viewModel?.formState.uploadedImages ?? []).indices, id: \.self) { index in
                                        if let images = viewModel?.formState.uploadedImages,
                                           index < images.count,
                                           let uiImage = UIImage(data: images[index]) {
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 120, height: 120)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                                Button {
                                                    viewModel?.formState.uploadedImages.remove(at: index)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.title3)
                                                        .foregroundStyle(.white, .red)
                                                }
                                                .offset(x: 6, y: -6)
                                            }
                                        }
                                    }

                                    // Add more button (max 3 photos)
                                    if (viewModel?.formState.uploadedImages ?? []).count < 3 {
                                        VStack {
                                            Image(systemName: "plus.circle")
                                                .font(.title)
                                                .foregroundStyle(BuildPeekColors.primaryBlue)
                                            Text("Add More")
                                                .font(.caption)
                                                .foregroundStyle(BuildPeekColors.primaryBlue)
                                        }
                                        .frame(width: 100, height: 120)
                                        .background(BuildPeekColors.primaryBlue.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                            .frame(height: 130)
                        }
                    }
                }
                .onChange(of: selectedPhotos) { _, newItems in
                    Task {
                        await loadSelectedPhotos(newItems)
                    }
                }
                .fadeSlideIn(delay: 0.1)

                // Loading indicator
                if isLoadingPhotos {
                    HStack {
                        ProgressView()
                        Text("Loading photos...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                // Renovation description
                FormSection(title: "Describe Your Renovation") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: Binding(
                            get: { viewModel?.formState.renovationDescription ?? "" },
                            set: { viewModel?.formState.renovationDescription = $0 }
                        ))
                        .frame(minHeight: 100)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            Group {
                                if viewModel?.formState.renovationDescription.isEmpty == true {
                                    Text("Example: I want to update my kitchen with modern white cabinets, quartz countertops, and new stainless steel appliances...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(16)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )

                        Text("Describe what renovations you'd like to make")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .fadeSlideIn(delay: 0.15)

                // Skip option
                if (viewModel?.formState.uploadedImages ?? []).isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentStep = .basics
                        }
                    } label: {
                        Text("Skip - Enter details manually")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }

        // MEMORY OPTIMIZATION: Process one image at a time with aggressive compression
        // Limit to 3 photos max to prevent memory issues
        let maxPhotos = 3
        let currentCount = viewModel?.formState.uploadedImages.count ?? 0
        let availableSlots = max(0, maxPhotos - currentCount)

        for item in items.prefix(availableSlots) {
            // Load and compress image data
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Compress on background thread, update UI on main thread
                let compressedData = compressImageForUpload(data)
                viewModel?.formState.uploadedImages.append(compressedData)
            }
        }

        // Clear selection to allow re-selection
        selectedPhotos = []
    }

    /// Compress image aggressively for memory efficiency
    /// Target: Max 800KB per image, max 1280px dimension
    private func compressImageForUpload(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }

        // Resize to max 1280px on longest side (reduced from 1920)
        let maxDimension: CGFloat = 1280
        let scale = min(maxDimension / max(image.size.width, image.size.height), 1.0)

        var resultImage = image
        if scale < 1.0 {
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            resultImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        // Compress with quality reduction until under 800KB
        var quality: CGFloat = 0.7
        var compressedData = resultImage.jpegData(compressionQuality: quality) ?? data

        while compressedData.count > 800 * 1024 && quality > 0.2 {
            quality -= 0.15
            compressedData = resultImage.jpegData(compressionQuality: quality) ?? compressedData
        }

        return compressedData
    }

    // MARK: - Step 1: Basics

    private var basicsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                FormSection(title: "Project Name") {
                    ModernTextField(
                        placeholder: "e.g., Kitchen Renovation 2025",
                        text: Binding(
                            get: { viewModel?.formState.projectName ?? "" },
                            set: { viewModel?.formState.projectName = $0 }
                        ),
                        icon: "pencil"
                    )
                }
                .fadeSlideIn(delay: 0.05)

                FormSection(title: "Room Type") {
                    RoomTypePicker(
                        selection: Binding(
                            get: { viewModel?.formState.roomType ?? .kitchen },
                            set: { viewModel?.updateRoomType($0) }
                        )
                    )
                }
                .fadeSlideIn(delay: 0.1)

                FormSection(title: "Square Footage") {
                    ModernTextField(
                        placeholder: "Enter square footage",
                        text: Binding(
                            get: { viewModel?.formState.squareFootage ?? "" },
                            set: {
                                viewModel?.formState.squareFootage = $0
                                viewModel?.updateBudgetFromSquareFootage()
                            }
                        ),
                        icon: "square.grid.2x2",
                        keyboardType: .decimalPad,
                        suffix: "sq ft"
                    )
                }
                .fadeSlideIn(delay: 0.15)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Step 2: Details

    private var detailsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                FormSection(title: "Location") {
                    VStack(spacing: 12) {
                        ModernTextField(
                            placeholder: "City, State",
                            text: Binding(
                                get: { viewModel?.formState.location ?? "" },
                                set: { viewModel?.formState.location = $0 }
                            ),
                            icon: "location"
                        )

                        ModernTextField(
                            placeholder: "ZIP Code",
                            text: Binding(
                                get: { viewModel?.formState.zipCode ?? "" },
                                set: { viewModel?.formState.zipCode = $0 }
                            ),
                            icon: "mappin.circle",
                            keyboardType: .numberPad
                        )
                    }
                }
                .fadeSlideIn(delay: 0.05)

                FormSection(title: "Quality Tier") {
                    QualityTierPicker(
                        selection: Binding(
                            get: { viewModel?.formState.qualityTier ?? .standard },
                            set: {
                                viewModel?.formState.qualityTier = $0
                                viewModel?.updateBudgetFromSquareFootage()
                            }
                        )
                    )
                }
                .fadeSlideIn(delay: 0.1)

                FormSection(title: "Timeline") {
                    UrgencyPicker(
                        selection: Binding(
                            get: { viewModel?.formState.urgency ?? .standard },
                            set: { viewModel?.formState.urgency = $0 }
                        )
                    )
                }
                .fadeSlideIn(delay: 0.15)

                FormSection(title: "Options") {
                    VStack(spacing: 0) {
                        ToggleRow(
                            title: "Include Permits",
                            subtitle: "Building permits and inspections",
                            isOn: Binding(
                                get: { viewModel?.formState.includesPermits ?? true },
                                set: { viewModel?.formState.includesPermits = $0 }
                            )
                        )

                        Divider()

                        ToggleRow(
                            title: "Include Design",
                            subtitle: "Professional design services",
                            isOn: Binding(
                                get: { viewModel?.formState.includesDesign ?? false },
                                set: { viewModel?.formState.includesDesign = $0 }
                            )
                        )
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .fadeSlideIn(delay: 0.2)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Step 3: Materials

    private var materialsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                FormSection(title: "Search Materials") {
                    ModernTextField(
                        placeholder: "Search materials...",
                        text: Binding(
                            get: { viewModel?.materialsSearchQuery ?? "" },
                            set: { viewModel?.searchMaterials($0) }
                        ),
                        icon: "magnifyingglass"
                    )
                }

                FormSection(title: "Selected (\(viewModel?.formState.selectedMaterials.count ?? 0))") {
                    if let materials = viewModel?.formState.selectedMaterials, !materials.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(Array(materials), id: \.self) { material in
                                SelectedMaterialChip(
                                    title: material,
                                    onRemove: {
                                        viewModel?.toggleMaterial(material)
                                    }
                                )
                            }
                        }
                    } else {
                        Text("No materials selected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                FormSection(title: "Available Materials") {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel?.filteredMaterials ?? [], id: \.id) { material in
                            MaterialRow(
                                material: material,
                                isSelected: viewModel?.formState.selectedMaterials.contains(material.name) ?? false,
                                onTap: {
                                    withAnimation(.spring(response: 0.3)) {
                                        viewModel?.toggleMaterial(material.name)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Step 4: Review

    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Photo summary (if photos uploaded)
                if let images = viewModel?.formState.uploadedImages, !images.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("\(images.count) Photo\(images.count > 1 ? "s" : "") Uploaded")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("AI Vision Enabled")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(images.indices, id: \.self) { index in
                                    if let uiImage = UIImage(data: images[index]) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .fadeSlideIn(delay: 0.02)
                }

                // Summary card
                VStack(spacing: 0) {
                    ReviewRow(label: "Project Name", value: viewModel?.formState.projectName ?? "Untitled")
                    Divider()
                    ReviewRow(label: "Room Type", value: viewModel?.formState.roomType.rawValue ?? "")
                    Divider()
                    ReviewRow(label: "Square Footage", value: "\(viewModel?.formState.squareFootage ?? "0") sq ft")
                    Divider()
                    ReviewRow(label: "Quality Tier", value: viewModel?.formState.qualityTier.rawValue ?? "")
                    Divider()
                    ReviewRow(label: "Location", value: viewModel?.formState.location.isEmpty == true ? "Not specified" : (viewModel?.formState.location ?? ""))
                    Divider()
                    ReviewRow(label: "Materials", value: "\(viewModel?.formState.selectedMaterials.count ?? 0) selected")
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .fadeSlideIn(delay: 0.05)

                // Budget estimate preview
                if let sqft = Double(viewModel?.formState.squareFootage ?? "0"), sqft > 0 {
                    BudgetPreviewCard(
                        sqft: sqft,
                        roomType: viewModel?.formState.roomType ?? .kitchen,
                        qualityTier: viewModel?.formState.qualityTier ?? .standard
                    )
                    .fadeSlideIn(delay: 0.1)
                }

                // Notes
                FormSection(title: "Additional Notes (Optional)") {
                    TextEditor(text: Binding(
                        get: { viewModel?.formState.notes ?? "" },
                        set: { viewModel?.formState.notes = $0 }
                    ))
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .fadeSlideIn(delay: 0.15)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep.rawValue > 0 {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = FormStep(rawValue: currentStep.rawValue - 1) ?? .basics
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            Button {
                if currentStep.rawValue < FormStep.allCases.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = FormStep(rawValue: currentStep.rawValue + 1) ?? .review
                    }
                } else {
                    generateEstimate()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentStep == .review ? "Generate Estimate" : "Continue")
                    Image(systemName: currentStep == .review ? "sparkles" : "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(currentStep == .basics && (viewModel?.formState.squareFootageValue ?? 0) <= 0)
            .opacity(currentStep == .basics && (viewModel?.formState.squareFootageValue ?? 0) <= 0 ? 0.5 : 1.0)
        }
    }

    private func generateEstimate() {
        showEstimateView = true
    }
}

// MARK: - Supporting Views

struct StepProgressView: View {
    let steps: [String]
    let currentStep: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? Color.blue : Color(.systemGray4))
                            .frame(width: 28, height: 28)

                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(index <= currentStep ? .white : .secondary)
                        }
                    }
                    .scaleEffect(index == currentStep ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: currentStep)

                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep ? Color.blue : Color(.systemGray4))
                            .frame(height: 2)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }
            }
        }
    }
}

struct FormSection<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
        }
    }
}

struct ModernTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var suffix: String? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(isFocused ? .blue : .secondary)
                    .frame(width: 24)
                    .animation(.spring(response: 0.3), value: isFocused)
            }

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .focused($isFocused)

            if let suffix = suffix {
                Text(suffix)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isFocused ? Color.blue : Color.clear, lineWidth: 2)
        )
        .animation(.spring(response: 0.3), value: isFocused)
    }
}

struct RoomTypePicker: View {
    @Binding var selection: RoomType

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(RoomType.allCases) { type in
                RoomTypeButton(
                    type: type,
                    isSelected: selection == type,
                    action: {
                        withAnimation(.spring(response: 0.3)) {
                            selection = type
                        }
                    }
                )
            }
        }
    }
}

struct RoomTypeButton: View {
    let type: RoomType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)

                Text(type.rawValue)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct QualityTierPicker: View {
    @Binding var selection: QualityTier

    var body: some View {
        VStack(spacing: 8) {
            ForEach(QualityTier.allCases) { tier in
                QualityTierRow(
                    tier: tier,
                    isSelected: selection == tier,
                    action: {
                        withAnimation(.spring(response: 0.3)) {
                            selection = tier
                        }
                    }
                )
            }
        }
    }
}

struct QualityTierRow: View {
    let tier: QualityTier
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.rawValue)
                        .font(.subheadline.weight(.medium))
                    Text(tier.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct UrgencyPicker: View {
    @Binding var selection: ProjectUrgency

    var body: some View {
        VStack(spacing: 8) {
            ForEach(ProjectUrgency.allCases) { urgency in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selection = urgency
                    }
                } label: {
                    HStack {
                        Text(urgency.rawValue)
                            .font(.subheadline)

                        Spacer()

                        if urgency.multiplier != 1.0 {
                            Text(urgency.multiplier > 1 ? "+\(Int((urgency.multiplier - 1) * 100))%" : "\(Int((urgency.multiplier - 1) * 100))%")
                                .font(.caption)
                                .foregroundStyle(urgency.multiplier > 1 ? .orange : .green)
                        }

                        if selection == urgency {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background(selection == urgency ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(selection == urgency ? Color.blue : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

struct MaterialRow: View {
    let material: MaterialItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(material.name)
                        .font(.subheadline)
                    Text(material.formattedPriceRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct SelectedMaterialChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }
            self.size.height = y + rowHeight
        }
    }
}

struct ReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .padding()
    }
}

struct BudgetPreviewCard: View {
    let sqft: Double
    let roomType: RoomType
    let qualityTier: QualityTier

    var estimatedRange: (low: Double, high: Double) {
        let range = roomType.averageCostPerSqFt
        let multiplier = qualityTier.multiplier
        return (sqft * range.lowerBound * multiplier, sqft * range.upperBound * multiplier)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Estimated Budget Range")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(formatCurrency(estimatedRange.low))
                    .font(.title2.bold())
                    .foregroundStyle(.green)

                Text("—")
                    .foregroundStyle(.secondary)

                Text(formatCurrency(estimatedRange.high))
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
            }

            Text("Based on \(roomType.rawValue) at \(qualityTier.rawValue) quality")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Preview

#Preview("Project Input") {
    ProjectInputView()
        .environment(AppState.shared)
        .modelContainer(for: RenovationProject.self, inMemory: true)
}
